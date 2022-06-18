REMOTEHOST0=isucon@54.178.196.217
REMOTEHOST1=isucon@3.112.34.175
REMOTEHOST2=isucon@13.113.90.76
REMOTEHOST3=isucon@54.178.196.217

TIMEID := $(shell date +%Y%m%d-%H%M%S)

# /etc/systemd/system/isucondition.go.service
# /etc/nginx/nginx.conf
# /etc/mysql/my.cnf
# /home/isucon/env.sh
# /home/isucon/webapp/go/go.*
# /home/isucon/webapp/go/*.go

build: isucondition

isucondition: main.go
	go build -o isucondition

deploy:
	go build -o isucondition
	ssh $(REMOTEHOST1) sudo systemctl stop isucondition.go
	scp isucondition $(REMOTEHOST1):~/webapp/go/isucondition
	scp env.sh $(REMOTEHOST1):~/env.sh
	cat isucondition.go.service | ssh $(REMOTEHOST1) sudo tee /etc/systemd/system/isucondition.go.service >/dev/null
	ssh $(REMOTEHOST1) sudo systemctl daemon-reload
	ssh $(REMOTEHOST1) sudo systemctl start isucondition.go

web1:
	ssh -L 13306:127.0.0.1:3306 $(REMOTEHOST1)
	# mysql -h 127.0.0.1 -P 13306 -uisucon -pisucon isucondition

fetch-prog:
	scp $(REMOTEHOST1):webapp/go/*.go .
	scp $(REMOTEHOST1):webapp/go/go.* .
	scp $(REMOTEHOST1):env.sh .

fetch-conf: # plan-B fetch
	mkdir -p files
	scp $(REMOTEHOST1):/etc/systemd/system/isucondition.go.service files
	scp $(REMOTEHOST1):/etc/nginx/nginx.conf files
	scp $(REMOTEHOST1):/etc/mysql/my.cnf files

pprof:
	go tool pprof -http="127.0.0.1:8081" logs/latest/cpu-web1.pprof 

.PHONY: schemaspy
schemaspy:
	mkdir -p -m 0777 schemaspy
	docker run --network host -v "${PWD}/schemaspy:/output" schemaspy/schemaspy:latest -t mysql -db isucondition -host 127.0.0.1 -port 13306 -s isucondition -u isucon -p isucon 
	python3 -m http.server -d schemaspy

########################################

# sudo apt etckeeper
# echo "* * * * * root sudo etckeeper commit autu-commit" | sudo tee /etc/cron.d/etckeeper

########################################

deploy-conf: #plan-A
	ssh $(REMOTEHOST1) sudo systemctl stop nginx
	scp web-1.nginx.conf $(REMOTEHOST1):/etc/nginx/nginx.conf
	ssh $(REMOTEHOST1) sudo systemctl start nginx
	ssh $(REMOTEHOST2) sudo systemctl stop nginx
	scp web-2.nginx.conf $(REMOTEHOST2):/etc/nginx/nginx.conf
	ssh $(REMOTEHOST2) sudo systemctl start nginx


collect-logs:
	mkdir -p logs/${TIMEID}
	rm -f logs/latest
	ln -sf ${TIMEID} logs/latest
	scp ${REMOTEHOST1}:/tmp/cpu.pprof logs/latest/cpu-web1.pprof
	ssh ${REMOTEHOST1} sudo chmod 644 /var/log/nginx/access.log
	scp ${REMOTEHOST1}:/var/log/nginx/access.log logs/latest/access-web1.log
	scp ${REMOTEHOST1}:/tmp/sql.log logs/latest/sql-web1.log
	ssh ${REMOTEHOST1} sudo truncate -c -s 0 /var/log/nginx/access.log
	ssh ${REMOTEHOST1} sudo truncate -c -s 0 /tmp/sql.log

truncate-logs:
	ssh ${REMOTEHOST1} sudo truncate -c -s 0 /var/log/nginx/access.log
	ssh ${REMOTEHOST1} sudo truncate -c -s 0 /tmp/sql.log
