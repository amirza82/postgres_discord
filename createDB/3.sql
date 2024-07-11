	#	View/Materialized View

1.
create view servers_channel_count as
select server_id, count(*) as channels from channel group by server_id

2.
create materialized view MV_events_in_2023_2024 as 
select * from event where (extract(year from start_date) between 2022 and 2025) or (extract(year from end_date) between 2022 and 2025)

#	creative

3. create a view that shows the members of each group
create view V_groups_member_count as
select group_id, count(*) from group_member group by group_id

4. create MV that lists servers created in 2024 along with thair channels and categories
create materialized view MV_server_2023 as
(select server.*, category_id, category_name, channel_id, channel_type_id, channel_name from server full outer join category using(server_id) full outer join channel using(category_id, server_id) where extract(year from creation_date) = 2023)


	#	Function

1.
create or replace function get_member_count_by_server_id(server_id int)
returns table (
		member_count bigint
) as $$
begin
return query select count(*) as member_count from server_member where server_member.server_id = get_member_count_by_server_id.server_id;
end;
$$ language plpgsql

--query:
--select * from get_member_count_by_server_id(5)

--2.
create or replace function change_server_nickname(user_id int, server_id int, nickname varchar(300))
returns integer
language plpgsql
as $$
begin
update nickname set nickname = change_server_nickname.nickname where nickname.server_id = change_server_nickname.server_id and nickname.user_id = change_server_nickname.user_id;
return 0;
end;
$$

--query:
--select * from nickname
--select change_server_nickname(779, 65, 'Johnn')

--#	creative

--3. make a function that returns the status of a user given their ID
create or replace function get_status_by_id(user_id int)
returns table(status varchar(30))
language plpgsql
as $$
begin
return query select status_text as status from "user" join status using(status_id) where "user".user_id = get_status_by_id.user_id;
end;
$$

--query:
--select get_status_by_id(5)

--4. a function that lists all the current events
create or replace function get_current_events()
returns table(event_id int)
language plpgsql
as $$
begin
return query select event.event_id from event where event.start_date < now() and event.end_date > now();
end;
$$

--query:
--select * from get_current_events()

insert into event (event_id, server_id, start_date, end_date) values (11, 1, '2020-01-01', '2025-01-01' )


	#	Trigger

--1.
create or replace function tg_1() returns trigger 
as $$
begin
if (not exists(select * from group_member, group_message, (select sender_id from message where message.message_id = new.message_id) as the_user_id where group_message.group_id = group_member.group_id and group_member.member_id = the_user_id.sender_id)) 
then raise exception 'the user is not a member of this group';
end if;
return new;
end;
$$ language 'plpgsql';
create or replace trigger check_member_in_group before insert on group_message
for each row
execute function tg_1();

--preq_query:
insert into message (message_id, sender_id, sent_date, message) values(1000, 2, now(), 'some text...')

--test_query:
--insert into group_message (message_id, group_id) values(1000, 1)


--2.
create or replace function tg_2()
returns trigger
language plpgsql
as $$
begin
if exists(select * from event where (new.start_date > event.start_date and new.start_date < event.end_date and new.server_id = event.server_id) or (new.end_date < event.end_date and new.end_date > event.start_date and new.server_id = event.server_id))
then raise exception 'the event overlaps with another event';
end if;
return new;
end;
$$;
create or replace trigger check_event_time_conflict
before insert on event
for each row execute function tg_2();

--test_query:
--insert into event(event_id, server_id, start_date, end_date) values (12, 1, '2025-01-01', '2026-01-01')

--#	creative

--3. before adding a new user, check for username uniqeness:

create or replace function tg_3()
returns trigger
language plpgsql
as $$
begin
if exists(select * from "user" where "user".username = new.username)
then raise exception 'username already exists';
end if;
return new;
end;
$$;
create or replace trigger check_username_unique before insert on "user"
for each row
execute function tg_3();

--test_query:
--insert into "user" (user_id, password,display_name, username) values (1001, '1234','potato', 'tparrot8c')

--4. same as 1, but for server_member and channel_message:
create or replace function tg_4()
returns trigger
language plpgsql
as $$
begin
if not exists(select * from 
		(select sender_id from message where message.message_id = new.message_id) as the_user_id,
		(select server_id from server join channel using(server_id) where channel_id = new.channel_id) as the_server_id
		where the_user_id.sender_id in(select member_id from server_member where server_member.server_id = the_server_id.server_id)
		 )
		 then raise exception 'user is not on this server';
end if;
return new;
end;
$$;
create or replace trigger check_user_in_server
before insert on server_message
for each row
execute function tg_4();

--test_query:
--insert into server_message (message_id, channel_id) values (128, 14)


	#	Stored Procedure

--1.
create or replace procedure add_group_member(group_id int, user_id int)
language sql
begin atomic
	insert into group_member values(user_id, group_id);
end;

--query:
--select * from group_member where member_id = 1
--call add_group_member(1, 1)

--2.
create or replace procedure add_friend(uid_1 int, uid_2 int)
begin atomic
	insert into friend values(uid_1, uid_2, now());
end;

--query:
--select * from friend where user_id_1 = 1
--call add_friend(1, 2)

--#	creative

--3. remove a user from a group given user_id and group_id
create or replace procedure remove_group_member(group_id int, user_id int)
language sql
as $$
	delete from group_member where group_member.group_id = remove_group_member.group_id and group_member.member_id = remove_group_member.user_id;
$$;

--query:
--call remove_group_member(1, 1)

--select * from group_member where member_id = 1

--4. delete a user's friend given user_id and the friend's id
create or replace procedure remove_friend(uid_1 int, uid_2 int)
begin atomic
	delete from friend where friend.user_id_1 = remove_friend.uid_1 and friend.user_id_2 = remove_friend.uid_2;
end;

--query:
--call remove_friend(1, 2)
--select * from friend where user_id_1 = 1
