
CREATE DATABASE IF NOT EXISTS election;
USE election;
CREATE USER IF NOT EXISTS 'election'@'localhost' IDENTIFIED BY 'election';
GRANT ALL ON election.* TO 'election'@'localhost';

-- TODO: CREATE TABLE ... 
