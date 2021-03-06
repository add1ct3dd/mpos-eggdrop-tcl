#
# Config File for eggdrop scripts
#
#
#
##################################################################
# General Config
##################################################################

set scriptversion "v0.7"

# time to wait before next command in seconds
#
set help_blocktime "5"

# debug mode
# set to 1 to display debug messages in partyline and logfile
#
set debug "0"

# debug output
# set to 1 to display json output
# beware, lots of data
#
set debugoutput "0"

# setting the output style
#
# -> CHAN   - put all infos in channel
# -> NOTICE - sends notice to the user who triggered the command
#
set output "CHAN"

# script path
# 
# path to tcl files
#
# if your script is installed in /usr/src/eggdrop/scripts/mininginfo/
# scriptpath is "./scripts/mininginfo/"
# 
set scriptpath "./scripts/mininginfo/"

# channels to advertise new block information
#
set channels "#channel1 #channel2"


##################################################################
# MPOS Config
##################################################################

# url where mpos is installed
#
set apiurl "https://yourmposapiurl/"

# api key from mpos
#
set apikey "YOURMPOSAPIKEY"

# setting coin name
#
set coinname "LTC"

# file to save last blocks
#
set lastblockfile "lastblock"

# file to save users
#
set registereduserfile "mposuser"

# confirmations before a block will be advertised
#
set confirmations "10"

# interval to check for new blocks in seconds
# if set to 0, the bot will do no automatic
# check for new blocks in seconds
#
set blockchecktime "60"


##################################################################
# Marketdata Config
##################################################################

# what market to use
#
# coins-e   -> 1
# vircurex  -> 2
# cryptsy   -> 3
#
# set to 0 to disable marketdata
#
set activemarket "3"

# api url
#
# Coins-E
# https://www.coins-e.com/api/v2/markets/data/
#
# Vircurex
# https://vircurex.com/api/get_highest_bid.json?base=NMC&alt=BTC
# 
# Cryptsy
# http://pubapi.cryptsy.com/api.php?method=singlemarketdata&marketid=
#
set marketapi "http://pubapi.cryptsy.com/api.php?method=singlemarketdata&marketid="

#
# only used if Coins-E Market is defined
#
# coinpair to query
# coinpair must be on api page, e.g. LTC_BTC
#
set coinse_querycoin "LTC_BTC"

#
# only used if Vircurex Market is defined
#
set vircurex_querycoin "LTC"

#
# only used if Cryptsy Market is defined
#
# cryptsy market id
# 
# get market id from trade in cryptsy portal
#
# Litecoin = 3
# Fastcoin = 44
# Feathercoin = 5
# Alphacoin = 57
#
set marketid "3"





