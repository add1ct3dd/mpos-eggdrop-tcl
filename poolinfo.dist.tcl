#
# Config File for eggdrop scripts
#
#
#
##################################################################
# General Config
##################################################################
#
# set as something unique, same value as coinname is fine.
set ns "COINNAME"

namespace eval $ns {
	unset ::ns

	variable scriptversion "v0.7"

	# time to wait before next command in seconds
	#
	variable help_blocktime "5"

	# debug mode
	# set to 1 to display debug messages in partyline and logfile
	#
	variable debug "0"

	# debug output
	# set to 1 to display json output
	# beware, lots of data
	#
	variable debugoutput "0"

	# setting the output style
	#
	# -> CHAN   - put all infos in channel
	# -> NOTICE - sends notice to the user who triggered the command
	#
	variable output "CHAN"

	# script path
	# 
	# path to tcl files
	#
	# if your script is installed in /usr/src/eggdrop/scripts/mininginfo/
	# scriptpath is "./scripts/mininginfo/"
	# 
	variable scriptpath "./scripts/mininginfo/"

	# channels to advertise new block information
	#
	variable channels "#channel1 #channel2"


	##################################################################
	# MPOS Config
	##################################################################

	# url where mpos is installed
	#
	variable apiurl "https://yourmposapiurl/"

	# api key from mpos
	#
	variable apikey "YOURMPOSAPIKEY"

	# setting coin name
	#
	variable coinname "LTC"

	# file to save last blocks
	#
	variable lastblockfile "lastblock"

	# file to save users
	#
	variable registereduserfile "mposuser"

	# confirmations before a block will be advertised
	#
	variable confirmations "10"

	# interval to check for new blocks in seconds
	# if set to 0, the bot will do no automatic
	# check for new blocks in seconds
	#
	variable blockchecktime "60"

	######################################################################
	##########           nothing to edit below this line        ##########
	######################################################################


	#
	# key bindings
	#
	bind pub - !pool [namespace current]::pool_info
	bind pub - !block [namespace current]::block_info
	bind pub - !last [namespace current]::last_info
	bind pub - !user [namespace current]::user_info
	bind pub - !round [namespace current]::round_info
	bind pub - !worker [namespace current]::worker_info
	bind pub - !balance [namespace current]::balance_info
	bind pub - !help [namespace current]::printUsage

	# start timer if set
	# and check if started when bot rehashes
	# prevent from double timers
	#
	if {$blockchecktime ne "0"} {
		# check if timer is running
		# else a rehash starts a new timer
		if {![info exists checknewblocks_running]} {
			if {$debug eq "1"} { putlog "Timer active" }
			
			utimer $blockchecktime checknewblocks
			set checknewblocks_running 1
		}
	}

	# checking for new blocks
	#

	proc checknewblocks {} {
		variable blockchecktime 
		variable channels 
		variable apiurl 
		variable apikey 
		variable debug 
		variable debugoutput 
		variable confirmations 
		variable scriptpath 
		variable lastblockfile
		
		package require http
		package require json
		package require tls
		
		if {$debug eq "1"} { putlog "checking for new blocks" }
		
		set action "index.php?page=api&action=getblocksfound&api_key="
		set advertise_block 0
		set writeblockfile "no"
		
		set last_block "null"
		set last_shares "null"
		set last_finder "null"
		set last_status "null"
		set last_confirmations "null"
		
		set newurl $apiurl
		append newurl $action
		append newurl $apikey
		
		# setting logfile to right path
		set logfilepath $scriptpath
		append logfilepath $lastblockfile
		
		if {[string match "*https*" [string tolower $apiurl]]} {
			set usehttps 1
		} else {
			set usehttps 0
		}  

		if {$usehttps eq "1"} {
			::http::register https 443 tls::socket
		}
		
		set token [::http::geturl "$newurl"]
		set data [::http::data $token]
		::http::cleanup $token
		if {$usehttps eq "1"} {
			::http::unregister https
		}
		
		if {$debugoutput eq "1"} { putlog "xml: $data" }
		
		if {$data eq "Access denied"} {
			foreach advert $channels {
				putquick "PRIVMSG $advert :Access to Newblockdata denied"
			}
		} elseif {$data eq ""} {
			if {$debug eq "1"} { putlog "no data: $data" }
		} else {

			if {[catch { set results [ [::json::json2dict $data] ]
				if {$debug eq "1"} { putlog "no data: $data" }
				utimer $blockchecktime checknewblocks
				return 0
			}]} {
				if {$debug eq "1"} { putlog "data found" }
			}

			set results [::json::json2dict $data]
			
			set blocklist {}
			
			foreach {key value} $results {
				#putlog "Key: $key - $value"
				foreach {sub_key sub_value} $value {
					#putlog "Sub1: $sub_key - $sub_value"
					if {$sub_key eq "data"} {
						#putlog "Sub2: $sub_value"
						foreach {elem} $sub_value {
							#putlog "Ele1: $elem"
							foreach {elem2 elem_val2} $elem {
								#putlog "Ele2: $elem2 - Val: $elem_val2"
								if {$elem2 eq "height"} { 
									set last_block "$elem_val2" 
									#putlog "Block: $elem_val2"
								}
								if {$elem2 eq "shares"} { set last_shares "Shares: $elem_val2" } 
								if {$elem2 eq "finder"} { set last_finder "Finder: $elem_val2" }
								if {$elem2 eq "confirmations"} {
									set last_confirmations $elem_val2
									if {$elem_val2 eq "-1"} {
										set last_status "Status: Orphan"
									} else {
										set last_status "Status: Valid | Confirmations: $elem_val2"
									}
								}
							}
							
							set advertise_block [check_block $last_block $last_confirmations]
							
							if {$advertise_block eq "0"} {
								#if {$debug eq "1"} { putlog "No New Block: $last_block" }
								lappend blocklist $last_block
							} elseif {$advertise_block eq "notconfirmed"} {
								#if {$debug eq "1"} { putlog "Block not confirmed" }
							} else {
								set writeblockfile "yes"
								advertise_block $last_block $last_status $last_shares $last_finder
								lappend blocklist $last_block
							}
							
						}
					}
				}
			}
		}
		
		if {$writeblockfile eq "yes"} {
			set fh [open $logfilepath w]
			foreach arr_elem $blocklist {
				#putlog "arr: $arr_elem"
				puts $fh [join $arr_elem "\n"]
			}
			close $fh
		} else {
			set lastblock [FileTextReadLine $logfilepath 0 0]
			putlog "No New Block found - $lastblock"
		}

		utimer $blockchecktime [namespace current]::checknewblocks
	}                                      
	  



	proc check_block {blockheight blockconfirmations} {
		variable debug 
		variable debugoutput 
		variable confirmations 
		variable scriptpath 
		variable lastblockfile
		
		#if {$debug eq "1"} { putlog "Checking Block: $blockheight" }

		# setting logfile to right path
		set logfilepath $scriptpath
		append logfilepath $lastblockfile
		
		if { [file_read $logfilepath] eq "0" } {
				
			# check if lastblocksfile exists
			#
			if { [file_check $logfilepath] eq "0" } {
				if {$debug eq "1"} { putlog "file $logfilepath does not exist" }
				if {[file_write $logfilepath new] eq "1" } { putlog "file $logfilepath created" }
			} else {
				if {$debug eq "1"} { putlog "can't read $logfilepath"}
			}

		} else {
		
			set blockfile [open $logfilepath]
			# Read until we find the start pattern
			while {[gets $blockfile line] >= 0} {
				#putlog "LINE: $line"
				if { [string match "$blockheight" $line] } {
					set newblock "0"
					break
				} else {
					set newblock $line
				}
			}
			close $blockfile
			
			if {$newblock ne "0"} {
				if {$blockconfirmations eq "-1"} {
					return $newblock
				} elseif {$blockconfirmations > $confirmations} {
					return $newblock
				} else {
					if {$debug eq "1"} { putlog "block not confirmed: $blockconfirmations - $confirmations" }
					return "notconfirmed"
				}
			} else {
				return "0"
			}

		}

	}


	proc advertise_block {newblock laststatus lastshares lastfinder} {
		variable channels 
		variable debug 
		variable debugoutput 
		variable scriptpath 
		variable lastblockfile 
		variable coinname

		# setting logfile to right path
		set logfilepath $scriptpath
		append logfilepath $lastblockfile
		
		set lastblock [FileTextReadLine $logfilepath 0 0]
		
		if {$debug eq "1"} { putlog "\[$coinname\] New Block: $newblock" }
		if {$debug eq "1"} { putlog "New / Last: $newblock - $lastblock" }
		
		foreach advert $channels {
			putquick "PRIVMSG $advert :\[$coinname\] New Block: #$newblock | Last Block: #$lastblock | $laststatus | $lastshares | $lastfinder"
		}

	}






	# info for specific user
	#

	proc user_info {nick host hand chan arg} {
		variable apiurl 
		variable apikey 
		variable help_blocktime 
		variable help_blocked 
		variable channels debug 
		variable debugoutput 
		variable output 
		variable coinname
		
		package require http
		package require json
		package require tls
		
		set action "index.php?page=api&action=getuserstatus&id=$arg&api_key="
		
		set mask [string trimleft $host ~]
		regsub -all {@([^\.]*)\.} $mask {@*.} mask	 	
		set mask *!$mask
	 
		if {[info exists help_blocked($mask)]} {
			  putquick "NOTICE $nick :You have been blocked for $help_blocktime Seconds, please be patient..."
			  return
		}
		
		set newurl $apiurl
		append newurl $action
		append newurl $apikey

		if {[string match "*https*" [string tolower $apiurl]]} {
			set usehttps 1
		} else {
			set usehttps 0
		}
		
		if {$usehttps eq "1"} {
			::http::register https 443 tls::socket
		}
		set token [::http::geturl "$newurl"]
		set data [::http::data $token]
		::http::cleanup $token
		if {$usehttps eq "1"} {
			::http::unregister https
		}
		
		if {$debugoutput eq "1"} { putlog "xml: $data" }
		
		if {$data eq "Access denied"} { 
			putquick "PRIVMSG $chan :Access to Userdata denied"
			return 0
		}
		
		set results [::json::json2dict $data]
		
		foreach {key value} $results {
			foreach {sub_key sub_value} $value {
				if {$sub_key eq "data"} {
					#putlog "Sub: $sub_value"
					foreach {elem elem_val} $sub_value {
						#putlog "Ele: $elem - Val: $elem_val"
						
						foreach {subelem subelem_val} $elem_val {
							#putlog "SubEle: $subelem - SubVal: $subelem_val"
							
							if {$subelem eq "valid"} { set user_validround "Valid this round: $subelem_val" }
							if {$subelem eq "invalid"} { set user_invalidround "Invalid this round: $subelem_val" }
							
						}
						
						if {$elem eq "hashrate"} { set user_hashrate "Hashrate: $elem_val kh/s" }
						if {$elem eq "sharerate"} { set user_sharerate "Sharerate: $elem_val S/s" }
					}
				}
			}
		}
		
		if {$output eq "CHAN"} {
			putquick "PRIVMSG $chan :\[$coinname\] User $arg: $user_hashrate | $user_validround | $user_invalidround | $user_sharerate"
		} elseif {$output eq "NOTICE"} {
			putquick "NOTICE $nick :\[$coinname\] User $arg: $user_hashrate | $user_validround | $user_invalidround | $user_sharerate"
		} else {
			putquick "PRIVMSG $chan :please set output in config file"
		}

		set help_blocked($mask) 1
		utimer $help_blocktime [ list unset [namespace current]::help_blocked($mask) ]

	}


	# round info
	#

	proc round_info {nick host hand chan arg } {
		variable apiurl
		variable apikey 
		variable help_blocktime 
		variable help_blocked 
		variable channels 
		variable debug 
		variable debugoutput 
		variable output 
		variable coinname
		
		package require http
		package require json
		package require tls
		
		set action "index.php?page=api&action=getdashboarddata&api_key="
		
		set mask [string trimleft $host ~]
		regsub -all {@([^\.]*)\.} $mask {@*.} mask	 	
		set mask *!$mask
	 
		if {[info exists help_blocked($mask)]} {
			  putquick "NOTICE $nick : You have been blocked for $help_blocktime Seconds, please be patient..."
			  return
		}

		set newurl $apiurl
		append newurl $action
		append newurl $apikey

		if {[string match "*https*" [string tolower $apiurl]]} {
			set usehttps 1
		} else {
			set usehttps 0
		}
		
		if {$usehttps eq "1"} {
			::http::register https 443 tls::socket
		}
		set token [::http::geturl "$newurl"]
		set data [::http::data $token]
		::http::cleanup $token
		if {$usehttps eq "1"} {
			::http::unregister https
		}
		
		if {$debugoutput eq "1"} { putlog "xml: $data" }
		
		if {$data eq "Access denied"} { 
			putquick "PRIVMSG $chan :Access to Roundinfo denied"
			return 0 
		}
		
		set results [::json::json2dict $data]
		
		foreach {key value} $results {
			#putlog "Key: $key - $value"
			foreach {sub_key sub_value} $value {
				#putlog "Sub: $sub_key - $sub_value"
				foreach {elem elem_val} $sub_value {
					#putlog "Ele: $elem - Val: $elem_val"
					
					
					if {$elem eq "pool"} {
						#putlog "Ele: $elem - Val: $elem_val"
						foreach {elem2 elem_val2} $elem_val {
							#putlog "Ele: $elem2 - Val: $elem_val2"
							if {$elem2 eq "shares"} {
								foreach {elem3 elem_val3} $elem_val2 {
									#putlog "Ele: $elem3 - Val: $elem_val3"
									
									if {$elem3 eq "valid"} { set shares_valid "$elem_val3" }
									if {$elem3 eq "invalid"} { set shares_invalid "$elem_val3" }
									if {$elem3 eq "estimated"} { set shares_estimated "Estimated Shares: $elem_val3" }
									if {$elem3 eq "progress"} { set shares_progress "Progress: $elem_val3 %" }
									
								}
							}
						}				
					}
					
					if {$elem eq "network"} {
						#putlog "Ele: $elem - Val: $elem_val"
						foreach {elem2 elem_val2} $elem_val {

							if {$elem2 eq "block"} { set net_block "Block: #$elem_val2" }
							if {$elem2 eq "difficulty"} { set net_diff "Difficulty: $elem_val2" }

						}				
					}				
					
				}
			}
		}
		
		set allshares [expr $shares_valid+$shares_invalid]

		if {$output eq "CHAN"} {
			putquick "PRIVMSG $chan :\[$coinname\] Round Info: $net_block | $net_diff | $shares_estimated | Sharecount: $allshares | Shares valid: $shares_valid | Shares invalid: $shares_invalid | $shares_progress"	
		} elseif {$output eq "NOTICE"} {
			putquick "NOTICE $nick :\[$coinname\] Round Info: $net_block | $net_diff | $shares_estimated | Sharecount: $allshares | Shares valid: $shares_valid | Shares invalid: $shares_invalid | $shares_progress"	
		} else {
			putquick "PRIVMSG $chan :please set output in config file"
		}
		
		set help_blocked($mask) 1
		utimer $help_blocktime [ list unset [namespace current]::help_blocked($mask) ]

	}


	# last block found
	#

	proc last_info {nick host hand chan arg } {
		variable coinname 
		variable apiurl 
		variable apikey 
		variable help_blocktime 
		variable help_blocked 
		variable channels 
		variable debug 
		variable debugoutput 
		variable output
		
		package require http
		package require json
		package require tls
		
		set action "index.php?page=api&action=getblocksfound&limit=1&api_key="
		
		set mask [string trimleft $host ~]
		regsub -all {@([^\.]*)\.} $mask {@*.} mask	 	
		set mask *!$mask
	 
		if {[info exists help_blocked($mask)]} {
			  putquick "NOTICE $nick : You have been blocked for $help_blocktime Seconds, please be patient..."
			  return
		}

		set last_block "null"
		set last_confirmed "null"
		set last_difficulty "null"
		set last_shares "null"
		set last_finder "null"
		set last_estshares "null"
		set last_timefound "null"
		
		set newurl $apiurl
		append newurl $action
		append newurl $apikey

		if {[string match "*https*" [string tolower $apiurl]]} {
			set usehttps 1
		} else {
			set usehttps 0
		}
		
		if {$usehttps eq "1"} {
			::http::register https 443 tls::socket
		}
		set token [::http::geturl "$newurl"]
		set data [::http::data $token]
		::http::cleanup $token
		if {$usehttps eq "1"} {
			::http::unregister https
		}
		
		if {$debugoutput eq "1"} { putlog "xml: $data" }
		
		if {$data eq "Access denied"} { 
			putquick "PRIVMSG $chan :Access to Lastblocks denied"
			return 0 
		}
		
		set results [::json::json2dict $data]
		
		foreach {key value} $results {
			#putlog "Key: $key - $value"
			foreach {sub_key sub_value} $value {
				#putlog "Sub: $sub_key - $sub_value"
				if {$sub_key eq "data"} {
					#putlog "Sub: $sub_value"
					foreach {elem elem_val} $sub_value {
						#putlog "Ele: $elem - Val: $elem_val"
						foreach {elem2 elem_val2} $elem {
							#putlog "Ele: $elem2 - Val: $elem_val2"

							if {$elem2 eq "height"} { set last_block "Last Block: #$elem_val2" }
							if {$elem2 eq "confirmations"} {
								if {"$elem_val2" eq "-1"} {
									set last_confirmed "Status: Orphaned"
								} else {
									set last_confirmed "Status: Valid | Confirmations: $elem_val2"
								}
							} 
							if {$elem2 eq "difficulty"} { set last_difficulty "Difficulty: $elem_val2" }
							if {$elem2 eq "time"} {
								set converttimestamp [strftime "%d.%m.%Y - %T" $elem_val2]
								set last_timefound "Time found: $converttimestamp" 
							}
							if {$elem2 eq "shares"} { set last_shares "Shares: $elem_val2" } 
							if {$elem2 eq "finder"} { set last_finder "Finder: $elem_val2" } 
							if {$elem2 eq "estshares"} { set last_estshares "Est. Shares: $elem_val2" } 
							
						}
						break
					}
				}
			}
		}
		
		if {$output eq "CHAN"} {
			putquick "PRIVMSG $chan :\[$coinname\] $last_block | $last_confirmed | $last_difficulty | $last_timefound | $last_shares | $last_estshares | $last_finder"
		} elseif {$output eq "NOTICE"} {
			putquick "NOTICE $nick :\[$coinname\] $last_block | $last_confirmed | $last_difficulty | $last_timefound | $last_shares | $last_estshares | $last_finder"
		} else {
			putquick "PRIVMSG $chan :please set output in config file"
		}
		
		set help_blocked($mask) 1
		utimer $help_blocktime [ list unset [namespace current]::help_blocked($mask) ]

	}


	# Pool Stats
	#

	proc pool_info {nick host hand chan arg} {
		variable apiurl 
		variable apikey 
		variable help_blocktime 
		variable help_blocked 
		variable channels 
		variable debug 
		variable debugoutput 
		variable output 
		variable coinname
		
		package require http
		package require json
		package require tls
		
		set action "index.php?page=api&action=getpoolstatus&api_key="
		
		set mask [string trimleft $host ~]
		regsub -all {@([^\.]*)\.} $mask {@*.} mask	 	
		set mask *!$mask
	 
		if {[info exists help_blocked($mask)]} {
			  putquick "NOTICE $nick : You have been blocked for $help_blocktime Seconds, please be patient..."
			  return
		}

		set newurl $apiurl
		append newurl $action
		append newurl $apikey

		if {[string match "*https*" [string tolower $apiurl]]} {
			set usehttps 1
		} else {
			set usehttps 0
		}
		
		if {$usehttps eq "1"} {
			::http::register https 443 tls::socket
		}
		set token [::http::geturl "$newurl"]
		set data [::http::data $token]
		::http::cleanup $token
		if {$usehttps eq "1"} {
			::http::unregister https
		}
		
		if {$debugoutput eq "1"} { putlog "xml: $data" }
		
		if {$data eq "Access denied"} { 
			putquick "PRIVMSG $chan :Access to Poolinfo denied"
			return 0
		}
		
		set results [::json::json2dict $data]

		foreach {key value} $results {
			foreach {sub_key sub_value} $value {
				#putlog "Sub: $sub_key - $sub_value"
				if {$sub_key eq "data"} {
					#putlog "Sub: $sub_value"
					foreach {elem elem_val} $sub_value {
						#putlog "Ele: $elem - Val: $elem_val"
					
						if {$elem eq "hashrate"} { set pool_hashrate "Hashrate: $elem_val kh/s" }
						if {$elem eq "efficiency"} { set pool_efficiency "Efficiency: $elem_val %" } 
						if {$elem eq "workers"} { set pool_workers "Workers: $elem_val" } 
						if {$elem eq "nethashrate"} { set pool_nethashrate "Net Hashrate: $elem_val kh/s" } 
					
					}
				}
			}
		}
		
		if {$output eq "CHAN"} {
			putquick "PRIVMSG $chan :\[$coinname\] Pool Stats: $pool_hashrate | $pool_efficiency | $pool_workers | $pool_nethashrate"	
		} elseif {$output eq "NOTICE"} {
			putquick "NOTICE $nick :\[$coinname\] Pool Stats: $pool_hashrate | $pool_efficiency | $pool_workers | $pool_nethashrate"	
		} else {
			putquick "PRIVMSG $chan :please set output in config file"
		}
		
	}


	# Block Stats
	#

	proc block_info {nick host hand chan arg} {
		variable apiurl 
		variable apikey 
		variable help_blocktime 
		variable help_blocked 
		variable channels 
		variable debug 
		variable debugoutput 
		variable output 
		variable coinname
		
		package require http
		package require json
		package require tls
		
		set action "index.php?page=api&action=getpoolstatus&api_key="
		
		set mask [string trimleft $host ~]
		regsub -all {@([^\.]*)\.} $mask {@*.} mask	 	
		set mask *!$mask
	 
		if {[info exists help_blocked($mask)]} {
			  putquick "NOTICE $nick : You have been blocked for $help_blocktime Seconds, please be patient..."
			  return
		}
		
		set newurl $apiurl
		append newurl $action
		append newurl $apikey

		if {[string match "*https*" [string tolower $apiurl]]} {
			set usehttps 1
		} else {
			set usehttps 0
		}
		
		if {$usehttps eq "1"} {
			::http::register https 443 tls::socket
		}
		set token [::http::geturl "$newurl"]
		set data [::http::data $token]
		::http::cleanup $token
		if {$usehttps eq "1"} {
			::http::unregister https
		}
		
		if {$debugoutput eq "1"} { putlog "xml: $data" }
		
		if {$data eq "Access denied"} { 
			putquick "PRIVMSG $chan :Access to Blockinfo denied"
			return 0
		}
		
		set results [::json::json2dict $data]
		
		foreach {key value} $results {
			foreach {sub_key sub_value} $value {
				if {$sub_key eq "data"} {
					#putlog "Sub: $sub_value"
					foreach {elem elem_val} $sub_value {
						#putlog "Ele: $elem - Val: $elem_val"

						if {$elem eq "currentnetworkblock"} { set block_current "Current Block: #$elem_val" } 
						if {$elem eq "nextnetworkblock"} { set block_next "Next Block: #$elem_val" } 
						if {$elem eq "lastblock"} { set block_last "Last Block: #$elem_val" }
						if {$elem eq "networkdiff"} { set block_diff "Difficulty: $elem_val" } 
						if {$elem eq "esttime"} {
							#set timediff [expr {$elem_val / 60}]
							set timediff [expr {double(round(100*[expr {$elem_val / 60}]))/100}]
							set block_time "Est. Time to resolve: $timediff minutes" 
						} 
						if {$elem eq "estshares"} { set block_shares "Est. Shares to resolve: $elem_val" } 
						if {$elem eq "timesincelast"} { 
							#set timediff [expr {$elem_val / 60}]
							set timediff [expr {double(round(100*[expr {$elem_val / 60}]))/100}]
							#set timediff $elem_val
							set block_timelast "Time since last Block: $timediff minutes"
						}
					
					}
				}
			}
		}
		
		if {$output eq "CHAN"} {
			putquick "PRIVMSG $chan :\[$coinname\] Block Stats: $block_current | $block_next | $block_last | $block_diff | $block_time | $block_shares | $block_timelast"	
		} elseif {$output eq "NOTICE"} {
			putquick "NOTICE $nick :\[$coinname\] Block Stats: $block_current | $block_next | $block_last | $block_diff | $block_time | $block_shares | $block_timelast"	
		} else {
			putquick "PRIVMSG $chan :please set output in config file"
		}
		
	}


	# Get Workers
	#

	proc worker_info {nick host hand chan arg} {
		variable apiurl 
		variable apikey 
		variable help_blocktime 
		variable help_blocked 
		variable channels 
		variable debug 
		variable debugoutput 
		variable output
		
		package require http
		package require json
		package require tls
		
		set action "index.php?page=api&action=getuserworkers&id=$arg&api_key="
		
		set mask [string trimleft $host ~]
		regsub -all {@([^\.]*)\.} $mask {@*.} mask	 	
		set mask *!$mask
	 
		if {[info exists help_blocked($mask)]} {
			  putquick "NOTICE $nick : You have been blocked for $help_blocktime Seconds, please be patient..."
			  return
		}
		
		set newurl $apiurl
		append newurl $action
		append newurl $apikey

		if {[string match "*https*" [string tolower $apiurl]]} {
			set usehttps 1
		} else {
			set usehttps 0
		}
		
		if {$usehttps eq "1"} {
			::http::register https 443 tls::socket
		}
		set token [::http::geturl "$newurl"]
		set data [::http::data $token]
		::http::cleanup $token
		if {$usehttps eq "1"} {
			::http::unregister https
		}
		
		if {$debugoutput eq "1"} { putlog "xml: $data" }
		
		if {$data eq "Access denied"} { 
			putquick "PRIVMSG $chan :Access to Workers denied"
			return 0
		}
		
		set results [::json::json2dict $data]
		
		foreach {key value} $results {
			foreach {sub_key sub_value} $value {
				if {$sub_key eq "data"} {
					#putlog "Sub: $sub_value"
					foreach {elem} $sub_value {
						#putlog "Ele: $elem"
						foreach {elem2 elem_val2} $elem {
							#putlog "Ele: $elem2 - Val: $elem_val2"
							
							if {$elem2 eq "username"} {
								#if {$elem_val2 ne $arg} {
								#	putquick "PRIVMSG $chan :Access to user $elem_val2 denied"
								#	return 0
								#}
								
								if {![info exists worker_name]} {
									set worker_name "$elem_val2"
								} else {
									append worker_name "$elem_val2"
								}
							} 
							if {$elem2 eq "hashrate"} { 
								if {![info exists worker_name]} {
									set worker_name " - $elem_val2 KH/s | " 
								} else {
									append worker_name " - $elem_val2 KH/s | "
								}
							} 						
						}
					}
				}
			}
		}
		
		# split message if buffer is to big
		#
		set len [expr {512-[string len ":$::botname PRIVMSG $chan :\r\n"]}] 
		foreach line [wordwrap $worker_name $len] { 
			if {$output eq "CHAN"} {
				putquick "PRIVMSG $chan :$line"	
			} elseif {$output eq "NOTICE"} {
				putquick "NOTICE $nick :$line"		
			} else {
				putquick "PRIVMSG $chan :please set output in config file"
				return 0
			}      
		}
		
	}


	# Account balance
	#

	proc balance_info {nick host hand chan arg} {
		variable apiurl 
		variable apikey 
		variable help_blocktime 
		variable help_blocked 
		variable channels debug 
		variable debugoutput 
		variable output 
		variable coinname
		
		package require http
		package require json
		package require tls
		
		set action "index.php?page=api&action=getuserbalance&id=$arg&api_key="
		
		set mask [string trimleft $host ~]
		regsub -all {@([^\.]*)\.} $mask {@*.} mask	 	
		set mask *!$mask
	 
		if {[info exists help_blocked($mask)]} {
			  putquick "NOTICE $nick : You have been blocked for $help_blocktime Seconds, please be patient..."
			  return
		}
		
		set newurl $apiurl
		append newurl $action
		append newurl $apikey

		if {[string match "*https*" [string tolower $apiurl]]} {
			set usehttps 1
		} else {
			set usehttps 0
		}
		
		if {$usehttps eq "1"} {
			::http::register https 443 tls::socket
		}
		set token [::http::geturl "$newurl"]
		set data [::http::data $token]
		::http::cleanup $token
		if {$usehttps eq "1"} {
			::http::unregister https
		}
		
		if {$debugoutput eq "1"} { putlog "xml: $data" }
		
		if {$data eq "Access denied"} { 
			putquick "PRIVMSG $chan :Access to Blockinfo denied"
			return 0
		}
		
		set results [::json::json2dict $data]
		
		foreach {key value} $results {
			foreach {sub_key sub_value} $value {
				if {$sub_key eq "data"} {
					#putlog "Sub: $sub_value"
					foreach {elem elem_val} $sub_value {
						#putlog "Ele: $elem - Val: $elem_val"
						
						if {$elem eq "confirmed"} { set balance_confirmed "Confirmed: $elem_val $coinname" } 
						if {$elem eq "unconfirmed"} { set balance_unconfirmed "Unconfirmed: $elem_val $coinname" } 
						if {$elem eq "orphaned"} { set balance_orphaned "Orphan: $elem_val $coinname" } 

					}
				}
			}
		}
		
		if {$output eq "CHAN"} {
			putquick "PRIVMSG $chan :\[$coinname\] Account Balance: $balance_confirmed | $balance_unconfirmed | $balance_orphaned"	
		} elseif {$output eq "NOTICE"} {
			putquick "NOTICE $nick :\[$coinname\] Account Balance: $balance_confirmed | $balance_unconfirmed | $balance_orphaned"	
		} else {
			putquick "PRIVMSG $chan :please set output in config file"
		}
		
	}


	# print bot usage info
	#

	proc printUsage {nick host hand chan arg} {
		putquick "NOTICE $nick :Usage:"
		putquick "NOTICE $nick :       !block <coin>                            - Blockstats"
		putquick "NOTICE $nick :       !pool <coin>                             - Pool Information"
		putquick "NOTICE $nick :       !round <coin>                            - Round Information"
		putquick "NOTICE $nick :       !last <coin>                             - Last found Block"
		putquick "NOTICE $nick :       !user <user> <coin>                      - User Information"
		putquick "NOTICE $nick :       !worker <user> <coin>                    - User Workers"
		putquick "NOTICE $nick :       !balance <user> <coin>                   - User Wallet Balance"
		putquick "NOTICE $nick :       !price <coin>                            - Get actual Coinprice"
		putquick "NOTICE $nick :       !help                                    - This help text"
	}



	# basic file operations
	#

	proc file_write {filename blocknumber {AUTOAPPEND 0} {NEWLINE 1}} {
		#set FILE [open $filename w]
		## write buffer
		#puts -nonewline $FILE $blocknumber
		## release and return 1 for OK
		#close $FILE
		#return 1


		# when no file exists or not autoappend is on = create/overwrite
		if {![file exists $filename] && $AUTOAPPEND!=1} then {
			# open for writemode
			set FILE [open $filename w]
		} else {
			# open for appendmode
			set FILE [open $filename a]
		}
		# write buffer
		if $NEWLINE {puts $FILE $blocknumber} {puts -nonewline $FILE $blocknumber}
		# release and return 1 for OK
		close $FILE
		return 1

	}

	proc file_read {filename} {
		# check exists and readable
		if {[file exists $filename] && [file readable $filename]} then {
			# open for readmode
			set FILE [open $filename r]
			set READ [read -nonewline $FILE]
			# release and return
			close $FILE
			return $READ
		} else {
			return 0
		}
	}

	proc file_check {filename} {
		# check file exists
		if [file exists $filename] then {
			# file exists
			return 1
		} else {
			# file not exists
			return "0"
		}
	}

	proc FileTextRead {FILENAME {LINEMODE 0}} {
		# check exists and readable
		if {[file exists $FILENAME] && [file readable $FILENAME]} then {
			# open for readmode
			set FILE [open $FILENAME r]
			if {$LINEMODE!=1} then {
				# read buffer
				set READ [read -nonewline $FILE]
			} else {
				# read line
				set READ [get $FILE]
			}
			# release and return
			close $FILE
			return $READ
		}
		# not readable
		return 0
	}

	proc FileTextReadLine {FILENAME LINENR {METHODE 1}} {
		# starts with LINENR 0 = line1, 1=line2, ..., 199=line200, ..

		proc ReadWithEof {FILE LINENR} {
			set ReadNUM 0
			# not end of file reached? read nexline
			while ![eof $FILE] {
				set LINE [gets $FILE]
				if {$LINENR==$ReadNUM} {return $LINE}
				incr ReadNUM
			}
			# failed
			return 0
		}

		proc ReadFullAndSplit {FILE LINENR} {
			# read full file
			set BUFFER [read -nonewline $FILE]
			# convert to a list
			set LIST [split $BUFFER \n]
			# return Result
			return [lindex $LIST $LINENR]
		}

		# check file and parameter, return when failed
		if {![file exist $FILENAME] || ![file readable $FILENAME] || ![string is digit $LINENR]} {return 0}
		# open file
		set FILE [open $FILENAME r]
		if {$METHODE!=1} {
			# use first read method
			set LINE [ReadWithEof $FILE $LINENR]
		} {
			# use second (default) read method
			set LINE [ReadFullAndSplit $FILE $LINENR]
		}
		close $FILE
		return $LINE
	}

	# wordwrap proc that accepts multiline data 
	# (empty lines will be stripped because there's no way to relay them via irc) 
	proc wordwrap {data len} { 
	   set out {} 
	   foreach line [split [string trim $data] \n] { 
		  set curr {} 
		  set i 0 
		  foreach word [split [string trim $line]] { 
			 if {[incr i [string len $word]]>$len} { 
				lappend out [join $curr] 
				set curr [list $word] 
				set i [string len $word] 
			 } { 
				lappend curr $word 
			 } 
			 incr i 
		  } 
		  if {[llength $curr]} { 
			 lappend out [join $curr] 
		  } 
	   } 
	   set out 
	}
	
	putlog "===>> Mining-Pool-Stats - Version $scriptversion loaded"

}