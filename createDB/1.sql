CREATE TABLE "user"
(
	user_id int not null,
	password varchar(30) not null,
	phone_number varchar(20),
	email varchar(200),
	join_date timestamp,
	username varchar(100) not null,
	display_name varchar(100) not null,
	status_id int,
	constraint user_pkey primary key (user_id)
);

create table role
(
	user_id int not null,
	server_id int not null,
	role varchar(60),
	constraint role_pkey primary key (user_id, server_id)
);

create table direct_message
(
	message_id int not null,
	reciver_id int not null,
	constraint direct_message_pkey primary key (message_id, reciver_id)
);

create table friend
(
	user_id_1 int not null,
	user_id_2 int not null,
	date timestamp,
	constraint friend_pkey primary key (user_id_1, user_id_2)
);

create table server_member
(
	member_id int not null,
	server_id int not null,
	constraint server_member_pkey primary key (member_id, server_id)
);

create table nickname
(
	user_id int not null,
	server_id int not null,
	nickname varchar(300),
	constraint nickname_pkey primary key (user_id, server_id)
);

create table status
(
	status_id int not null,
	status_text varchar(30),
	constraint status_pkey primary key (status_id)
);

create table message
(
	message_id int not null unique,
	sender_id int not null,
	attachment_id int,
	sent_date timestamp,
	message varchar(2000),
	constraint message_pkey primary key (message_id, sender_id)
);

create table event
(
	event_id int not null,
	server_id int not null,
	location varchar(100),
	topic varchar(100),
	start_date timestamp,
	end_date timestamp,
	description varchar(6000),
	creator_id int,
	constraint event_pkey primary key (event_id, server_id)
);

create table server
(
	server_id int not null,
	owner_id int,
	name varchar(70),
	creation_date timestamp,
	primary key (server_id)
);

create table "group"
(
	group_id int not null,
	group_name varchar(60),
	owner_id int,
	primary key (group_id)
);

create table attachment
(
	attachment_id int not null,
	attachment_file bytea,
	primary key (attachment_id)
);

create table category
(
	server_id int not null,
	category_id int not null unique,
	category_name varchar(50),
	is_privet boolean,
	primary key (server_id, category_id)
);

create table group_member
(
	member_id int not null,
	group_id int not null,
	primary key (member_id, group_id)
);

create table group_message
(
	message_id int not null,
	group_id int not null,
	primary key (message_id, group_id)
);

create table channel
(
	server_id int not null,
	channel_id int not null unique,
	category_id int,
	channel_type_id int,
	is_privet boolean,
	channel_name varchar(60),
	primary key (server_id, channel_id)
);

create table channel_type
(
	channel_type_id int not null,
	channel_type varchar(20),
	primary key (channel_type_id)
);

create table server_message
(
	message_id int not null,
	channel_id int not null,
	primary key (message_id, channel_id)
);


-- creating foreign key


alter table role add foreign key (user_id) REFERENCES "user"(user_id);
alter table role add foreign key (server_id) REFERENCES server(server_id);

alter table "user" add foreign key (status_id) REFERENCES status(status_id);

alter table direct_message add foreign key (message_id) REFERENCES message(message_id);
alter table direct_message add foreign key (reciver_id) REFERENCES "user"(user_id);
--
alter table friend add foreign key (user_id_1) REFERENCES "user"(user_id);
alter table friend add foreign key (user_id_2) REFERENCES "user"(user_id);

alter table server_member add foreign key (member_id) REFERENCES "user"(user_id);
alter table server_member add foreign key (server_id) REFERENCES server(server_id);

alter table nickname add foreign key (user_id) REFERENCES "user"(user_id);
alter table nickname add foreign key (server_id) REFERENCES server(server_id);
--
alter table message add foreign key (sender_id) REFERENCES "user"(user_id);
alter table message add foreign key (attachment_id) REFERENCES attachment(attachment_id);

alter table event add foreign key (server_id) REFERENCES server(server_id);
alter table event add foreign key (creator_id) REFERENCES "user"(user_id);

alter table server add foreign key (owner_id) REFERENCES "user"(user_id);

alter table "group" add foreign key (owner_id) REFERENCES "user"(user_id);

alter table category add foreign key (server_id) REFERENCES server(server_id);
--
alter table group_member add foreign key (member_id) REFERENCES "user"(user_id);
alter table group_member add foreign key (group_id) REFERENCES "group"(group_id);

alter table group_message add foreign key (message_id) REFERENCES message(message_id);
alter table group_message add foreign key (group_id) REFERENCES "group"(group_id);
--
alter table channel add foreign key (server_id) REFERENCES server(server_id);
alter table channel add foreign key (category_id) REFERENCES category(category_id);
alter table channel add foreign key (channel_type_id) REFERENCES channel_type(channel_type_id);

alter table server_message add foreign key (message_id) REFERENCES message(message_id);
alter table server_message add foreign key (channel_id) REFERENCES channel(channel_id);

