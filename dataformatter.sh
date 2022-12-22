#!/bin/bash

#number of arguments must be 1
if [[ $# != 1 ]]
then 
	echo "Usage: ./dataformatter.sh sensorlogdir"
	exit 1
fi

startdir=$1

# check if argument is valid directory
if [[ ! -d $startdir ]]
then
	echo "Error! $startdir is not a valid directory name"
	exit 1
fi

sensorErrors=""

# for each logfile that 'find' finds
for logfile in $(find $startdir -name 'sensordata-*.log' -type f)
do
	
	echo "Processing sensor data set for $logfile"

	# replace dashes in date to space, remove minute and second portions of time and pipe to awk
	sed -e 's/-/ /' -e 's/-/ /' -e 's/:..:..//g' < $logfile |  
	
	# change OFS to commas, and every line there's 'readouts': if there's an ERROR, 
	# replace error with previous line's sensor reading value 	
	awk ' BEGIN { OFS = ","; p1 =""; p2 =""; p3=""; p4=""; p5=""; print "Year,Month,Hour,Sensor1,Sensor2,Sensor3,Sensor4,Sensor5" } 
	/readouts/ {
		
		c1=$7; c2=$8; c3=$9; c4=$10; c5=$11;
		{ if (c1 == "ERROR") { c1=p1  } if (c2 == "ERROR") { c2=p2 } if (c3 == "ERROR") { c3=p3 } if (c4 == "ERROR") { c4=p4 } if (c5 == "ERROR") { c5=p5 } }
		p1=c1; p2=c2; p3=c3; p4=c4; p5=c5; print $1, $2, $3, $4, c1, c2, c3, c4, c5
		
		} END { print "====================================" }'

	echo "Readout statistics"

	# clean up date and time, pipe to awk same as above
	sed -e 's/-/ /' -e 's/-/ /' -e 's/:..:..//g' < $logfile |
	# change OFS to commas, and every line there's 'readouts': loop through each line's temperature fields, find the max and min values
	# print the appropriate fields
	awk ' BEGIN { OFS = ","; maxtemp=0; maxsensor=0; mintemp=0; minsensor=0; print "Year,Month,Hour,MaxTemp,MaxSensor,MinTemp,MinSensor" } 
	/readouts/ { 
	
		if ($7 != "ERROR") { maxtemp=$7; mintemp=$7 }
			else if ($8 != "ERROR") { maxtemp=$8; mintemp=$8 }
			else if ($9 != "ERROR") { maxtemp=$9; mintemp=$9 }
			else if ($10 != "ERROR") { maxtemp=$10; mintemp=$10 }
			else { maxtemp=$11; mintemp=$11 } 
				
		{ for (i=7; i<=NF; i++) if ($i == "ERROR") { continue } else if ($i>maxtemp) { maxtemp=$i; maxsensor = i - 6 } }
		{ for (n=7; n<=NF; n++) if ($n == "ERROR") { continue } else if ($n<mintemp) { mintemp=$n; minsensor = n - 6 } }

		print $1, $2, $3, $4, maxtemp, "Sensor"maxsensor, mintemp, "Sensor"minsensor

		} END { print "====================================" } '
	# append the sensor error results of each logfile to $sensorErrors (which was initialized outside of this logfile loop)
	# at the END of awk, print an extra space character (which will add a space between different logfile results)
	# the OFS is still commas 	
	sensorErrors=${sensorErrors}$(sed -e 's/-/ /' -e 's/-/ /' -e 's/:..:..//g' < $logfile |
	
	awk ' BEGIN { OFS=","; s1error=0; s2error=0; s3error=0; s4error=0; s5error=0 } 
	/readouts/ {

		{ for (i=7; i<=NF; i++) if ($i == "ERROR" && i == 7) { s1error += 1 } else if ($i == "ERROR" && i == 8) { s2error += 1 }
		else if ($i == "ERROR" && i == 9) { s3error += 1 } else if ($i == "ERROR" && i == 10) { s4error += 1 } 
		else if ($i == "ERROR" && i == 11) { s5error += 1 } }
	
		} END { print $1, $2, $3, s1error, s2error, s3error, s4error, s5error, (s1error + s2error + s3error + s4error + s5error), " " } ')

done
echo "Sensor error statistics"
echo "Year,Month,Day,Sensor1,Sensor2,Sensor3,Sensor4,Sensor5,Total"
# $sensorErrors contains error readings for logfiles in one line, with different logfile's results separated by a space
# use sed to replace the spaces with a newline, which will create a row for each logfile's results
# sed again to remove the last character of each row (which is a comma), and then sort
echo $sensorErrors | sed 's/ /\n/g' | sed 's/.$//g' | sort -t ',' -k 9nr -k 2,3n
echo "===================================="
