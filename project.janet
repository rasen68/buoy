(declare-project
	:name "buoy"
	# :description "make buoys description later"
	:dependencies [	"https://github.com/andrewchambers/janet-sh"
									"https://github.com/janet-lang/spork"]
)

(declare-executable
	:name "buoy-client"
	:entry "buoy-client.janet"
)

(declare-executable
	:name "buoy-server"
	:entry "buoy-server.janet"
)




