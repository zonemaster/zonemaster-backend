-- Initial setup of PostgreSQL database
create user zonemaster WITH PASSWORD 'zonemaster';
create database zonemaster;
GRANT ALL PRIVILEGES ON DATABASE zonemaster to zonemaster;
