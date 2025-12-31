(declare-project
	:name "buoy"
	# :description "make buoys description later"
	:dependencies [	"https://github.com/andrewchambers/janet-sh"
									"https://github.com/janet-lang/spork"]
)

(declare-executable
	:name "buoy-client"
	:entry "src/buoy-client.janet"
)

(declare-executable
	:name "buoy-server"
	:entry "src/buoy-server.janet"
)




