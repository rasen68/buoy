#!/usr/local/bin/janet

(import ./connection-tools :as nettools)

#this routine will send data and then read from other pipe

#assume the server has already created these pipes

(defn usage [status] 
	(print "echo -e \"buoy: usage: \\tbuoy -e <command> \\n\\t\\tbuoy [-m | -c] <string>\" >&2 ")
	#put more usage stuff here	
	(os/exit status ) 
)

(defn client-loop [ msg sockname ] 

	#blocks, we cant create read pipe until there is data on the other side
	#in other words, this blocks until we have a writer
	#(var read-pipe (file/open "/tmp/janet-out" :r ) )
	#(def write-pipe (file/open outpipe :w ) )

	(def connection (net/connect :unix sockname))
	
	(def managed-connection (nettools/make-connectionManager connection) )
	
	#(net/write connection msg )
	(:sendManaged managed-connection msg)

	(print (:acceptManaged managed-connection ) )
	#(print (net/read connection 1024))	
)

(defn prepare-and-send [argsarray sock] 
	
		#remove $0 and flag
		(var command-array (array/slice argsarray 2 ) )
		#all backslashes become double backslashes, so it is impossible for
		#the new string to contain " \ "
		(set command-array (map (fn [x] (string/replace-all "\\" "\\\\" x )) command-array )   )
		(def command-joined (string/join command-array " \\ "))
	
		#\\e will indicate the end of the message as the last arg being \e
		#(client-loop (string command-joined " \\ \\e" )  sock)
		#disable end flag logic for now, lets just assume all commands are under a certain size for now
		(client-loop command-joined sock)

)

(defn make-get-value-wrapper [args sock]
	#add the value (path) to the end of the args array
	#if an arg was specified, it is assumed to be relative to the current directory
	#there is currently no error checking to determine if the path actually exists
	
	#remove any args after the key
	(def newargs (array/slice args 0 3)) 

	(var appendpath "")
	(when (>= (length args) 4) 
		#we have to append it to cwd
		(set appendpath (get args 3) ) 
	)
	(array/push newargs 
		(if (or (string/has-prefix? "/" appendpath) (string/has-prefix? "~" appendpath))
			(string appendpath)
			(string (os/cwd) "/" appendpath )
		)
	)

	(prepare-and-send newargs sock)		
)

(defn make-check-valid-key-wrapper [args sock]
	#this function will check that a make command (buoy -m) has a key that fulfills the criteria
	#(def validpeg (regex/compile "^[a-zA-Z0-9,._+:@%/-]*$" ) )
	(def validpeg
		#pegs are always anchored at the beginning of the input, so there is no way to specify ^ or $
		(peg/compile 
			'(sequence
				(any 
					(choice 
						(set ",._+:%-" ) #notably, @ and / are excluded
						(range "az" "AZ" "09" )
					)
				)
				-1 #asserts that there is no input left, like $
			)
		)
	)

	(if (>= (length args) 3) 
		(do 
			(def buoy-key (get args 2 ) )
			(if (peg/match validpeg buoy-key )
				(make-get-value-wrapper args sock )
				(string "echo \"buoy: key " buoy-key " contains special characters.  Please use a different key\" >&2")
			)
		)
		(string "echo \"buoy: No Buoy Key Provided\" >&2 ")
	)
)

(defn sub-check-has-args-wrapper [args sock]
	#make sure we have at least one function to operate on, or else output will just be empty string which is undefined behavior
	(if (>= (length args ) 3 )
		(prepare-and-send args sock)	
		(string "echo \"buoy: No command to evaluate\" >&2 ")	
	)
)

(defn send-cd [args sock]
	(prepare-and-send [ "dummy" "dummy" "cd" (string "@" (get args 2) ) ] sock)
)

#not robust option checking because i suck
(defn checkopt [msock esock] 
	(let [args (dyn :args)]
		(case (get args 1)
			"-m" (make-check-valid-key-wrapper args msock )
			"-e" (sub-check-has-args-wrapper args esock )
			"-c" (send-cd args esock)
			"-h" (usage 0)
			(usage 1) # got nothing
		)
	)
)

(defn main [& args]
	
	(def socketdir (string (os/getenv "XDG_RUNTIME_DIR") "/buoy/") )

	(def msock (string socketdir "buoy-maker.socket" ) )
	(def esock (string socketdir "buoy-substitute.socket" ) )

	#don't pass in args, janet lets us get the args at any time via (dyn :args)
	(print (checkopt msock esock))
)
