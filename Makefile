psql ?= psql

genome_user:
	$(psql) -c 'DROP ROLE IF EXISTS genome'
	$(psql) -c 'CREATE ROLE genome WITH login'

remove_old_test_databases:
	$(psql) -l | awk '{ if ($$3 =="genome") {  print $$1 } }' | xargs --no-run-if-empty -n1 dropdb

test_db_master:
	$(psql) -c 'DROP DATABASE if exists test_db_master'
	$(psql) -c 'create database test_db_master'

sqitch_deploy:
	( cd sqitch && sqitch deploy )

clean: remove_old_test_databases genome_user test_db_master sqitch_deploy

test: clean
	prove -l

.PHONY: genome_user remove_old_test_databases test_db_master sqitch_deploy clean test
