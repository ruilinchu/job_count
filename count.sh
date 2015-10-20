#!/bin/bash
. /opt/lsf/conf/profile.lsf 
cd /home/rc200/util/job_count
mkdir -p data

fnow=$(date +"%Y-%m-%d.%H")

bhosts -w | awk '{
if( $5 >= 1 ) {
  print $1
  print "------ ------"
  print "ssh -o ConnectTimeout=40 " $1 " \"top -n1 -b | head -n" 23 "| tail -n " 16 "\" " | "/bin/sh"
  close("/bin/sh")
  print " "
}
}' > data/host_jobs.txt  2> data/error.out

awk '{
if($2 != "root" && $9 >30 ){
  for (i=1;i<=int(($9-20)/100)+1;i++)
    print $12
}
}' data/host_jobs.txt | sort | uniq -c | awk '{ if($1>4){ print $2,$1 } }' | sort -n -k 2,2 -r > data/job_count_$fnow.txt

while read -r c1 c2
do
echo $c1 total $c2
echo "--------------"
awk -v var="$c1" '{
if( $12 == var && $9 > 30 ){
  for (i=1;i<=int(($9-20)/100)+1;i++)
    print $2
}
}' data/host_jobs.txt | sort | uniq -c | awk '{print $2,$1}'| sort -n -k 2,2 -r 
echo "=============="
echo " "
done < data/job_count_$fnow.txt > data/job_count-u_$fnow.txt

cat > job_count.json << 'EOF'
{
"name": "flare",
 "children": [
EOF

while read -r c1 c2
do
echo {
echo \"name\": \"$c1\",
echo \"children\": [
awk -v var="$c1" '{
if( $12 == var && $9 > 30 ){
  for (i=1;i<=int(($9-20)/100)+1;i++)
    print $2
}
}' data/host_jobs.txt | sort | uniq -c | awk '{ print "{\"name\":\"", $2,"\",", " \"size\": ", $1, "},"  }'
echo {}]
echo },
done < data/job_count_$fnow.txt >> job_count.json

cat >>  job_count.json << 'EOF'
{}]
}
EOF

echo Running job counts on orchestra > datefile.txt
echo By Jimi Chu, HMS RC >> datefile.txt
date >> datefile.txt
/opt/ritg-util/bin/watch_queues | grep shared_hosts | awk '{print "cluster utilization: " $2, $3}' >> datefile.txt


cp datefile.txt /www/orchestra.med.harvard.edu/docroot/job_count/
cp job_count.json /www/orchestra.med.harvard.edu/docroot/job_count/

git add job_count.json datefile.txt
git commit -m "update"
git push origin gh-pages
