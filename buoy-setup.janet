#!/usr/local/bin/janet

# for testing, we should create input and output pipes / streams, and then fork to create a background process

#include spork here as well?
#should import sport instead of use spork to not clog namespace
#(import sport)

#this import is installed globally, and only really works if I shebang the script
#in the future, I should configure a project.janet that works to compile this file with deps
#(import sh)
(use sh)
(import spork/json)

#stupid unnamed pipes
#these are bound to this jaet event loop, and are not storeed on disk (other processes can't access)
#(def (janet_recv janet_send ) (os/pipe))

# communications between just janet event loop called processes should be done in channels

(defn surround [data surround]
	(string surround data surround)
)


# make named pipe with full permissions, @name should be a path in /tmp 
(defn make-socket [name] 
	#on linux we could use abstract uds but don't want to in case i have to use these on mingw at work (involves kernel)
	#(net/connect :unix name) #client

	(when (os/stat name) (os/rm name))

	(def sock (net/listen :unix name))

	(os/chmod name 8r777) #For some reason pipes made from janet don't have default /tmp/ permissions
	sock
)


# add necessary escape characters to a string if it is not interpreted to be a
(defn escape-string [arg]
	#escape rules as follows:
		# all normal bash operators can be escaped with a single \ in the initial input.  Bash will eat this \, and we will get the operator
		# if the user wants the operator to be escaped in the final output, they will need to escape it with a \\

	# Case 1: buoy -e ...|... = pipe will executed by bash and this program will never see it
	# Case 2: buoy -e ...\|... = This program's output command will execute the pie
	# Case 3: buoy -e ...\\|... = This program's output will include the pipe character (escaped)
	# Case 4: buoy -e "...|..." = Same as Case 2
	# Case 5:	buoy -e '...\|...'
	#					OR
	#					bouy -e "\'...|...\'" = Same as Case 3
	# We have provided syntax helper @@:
	# 	bouy -e @@"...|..." Which is equivalent to the third case (using SINGLE quotes)
	#if user wants double-quotes functionality, they will have to write it as "\"...\""

	#of course, this means that if you want an argument that begins with @@ in the final output, you will need to Case 3 escape it, a la buoy -e \\@@

	#where this is a pain: If a user wants to input a quoted string with spaces, they will need to escape it using case 3 syntax, where bash would normally only require case 2
	
	#use bash's build in escaping
	($< printf %q ,arg )
)

(defn substitute [argstring send recv ]
	#argument delimiter created by sending routine
	(var args (string/split " \\ " argstring))

	(def trueargs 
		(map 
			(fn [x] 
				(string/replace-all "\\\\" "\\" x )
			)
		args
		)
	)

	(ev/give send trueargs)
	(ev/take recv)
)


(defn server-loop [sockname func send-chan recv-chan ]

	(var buf @"")
	
	(print "server loop started")
	(def sock (make-socket sockname) )

	(forever
		#wait for client
		(def connection (net/accept sock ))
		(defer (:close connection)
			(set buf (net/read connection 1024) )

			#Send back the result of the operation
			(net/write connection (func buf send-chan recv-chan ) )
		)	
	)
)

(defn addkey [ argstring send recv ]
	(var args (string/split " \\ " argstring))

	#2 args enforced by client routine
	#(def t {:key (get args 0 ) :value (get args 1) } )
	(ev/give send args)

	# return the string from table manager, which
	# is an exceutable (evaluatable) bash script
	(ev/take recv)
)

(defn decode-json-if-exists [fname]
	(var t @{})
	(when (os/stat fname) 
		(set t
			(json/decode (slurp fname ) )
		)
	)
	t	
)

(defn write-json-to-file  [t fname]
	(with [f (file/open fname :w ) ] 
		(file/write f 
			(json/encode t "" "\n" )
		)
	)
)

(defn table-manager [make-recv make-send sub-recv sub-send ]
	(def datadir (string (os/getenv "HOME" ) "/.local/share/buoy/" ) )
	(def tablepath (string datadir "buoytable.json" ))
	(os/mkdir datadir) #would return falso if dir already exists

	(var buoys (decode-json-if-exists tablepath ) )	

	# buoy table substituter and updater functions are run as seperate fibers,
	# but need to be defined within this function so that they can access the
	# buoy table (since buoy table is not global)
	
	(defn updater [] 
		(forever
			#table of form {:key k :value v}
			(var item (ev/take make-recv ) )
			(def newkey (get item 0 ) )
			(def newvalue (get item 1 ) )

			(var return-msg 
				(string 
					"echo \" Successfully added key @"
					newkey
					" with value " 
					newvalue
					" to table\"" 
				) 
			)
			
			(when (get buoys newkey)
				(set return-msg
					(string
						"echo \" Warning: key @"
						newkey
						" already exists. Replaced old value ("
						(get buoys newkey)
						") with new value ("
						newvalue
						")\""
					)
				)
			)

			(put buoys (get item 0 ) (escape-string (get item 1 ) ) )

			# write updated table to filesystem
			(write-json-to-file buoys tablepath )
			
			#return string indicating success status
			(ev/give make-send return-msg)	
		)
	)

	(defn replacer [] 
		(forever
			#comes from substitute function as a list of all args in the script we need to replace
			(def args (ev/take sub-recv))
			(def out @[])

			(each arg args
				# check if we have asked for an arg
				(var outarg arg)
				(when (= (string/slice arg 0 1) "@" ) 

					# allow for escape string (@@ escapes the entirety of its arg)
					(set outarg 
						(escape-string 
							(if (= (string/slice arg 1 2) "@" ) 
						
								#escape the whole arg
								 (string/slice arg 2 )

								#else, dereference the buoy
								#buoys can be appended to by further files/filepaths.
								#we will find the first instance of
								#a /, and the buoy will be everything before that
								(do
									(var slashind (string/find "/" arg) )
									#we will split at the end, i.e. the buoy is the entire string
									(var secondhalf "")
									(if (nil? slashind)
										(set slashind (length arg))
										(set secondhalf (string/slice arg slashind) )
									)
									(string
										# remove the @
										(buoys (string/slice arg 1 slashind ) )
										# rest of the arg if additional is given
										secondhalf
									)
								)
							)
						)
					)
				)	
				#without @, it is the users responsibility to do the escaping
				(array/push out outarg) 
			)
			
			# return args joined as an expression
			(ev/give sub-send (string/join out " ") )
			
		)	
	)

	(ev/go updater)
	(ev/go replacer)
		
)	




#main routine

(def makesockname "/tmp/buoy-maker.socket")
(def subsockname "/tmp/buoy-substitute.socket")

#make channels for communicating with the table manager
(def make-in (ev/chan 5 ) )
(def make-out (ev/chan 5) )
(def sub-in (ev/chan 5 ) )
(def sub-out (ev/chan 5) )

(ev/go |(server-loop makesockname addkey make-in make-out )  )
(ev/go |(server-loop subsockname substitute sub-in sub-out ) )
(ev/go |(table-manager make-in make-out sub-in sub-out ) ) 
