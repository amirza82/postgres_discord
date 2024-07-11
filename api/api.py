from datetime import date, datetime, timedelta, timezone
from typing import Annotated, Union, List
import psycopg2
from enum import Enum
import jwt
from fastapi import Depends, FastAPI, HTTPException, status, Path
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jwt.exceptions import InvalidTokenError
from passlib.context import CryptContext
from pydantic import BaseModel
import atexit


# Remove later----------------------------------------
SECRET_KEY = 'ff1cba12a0a8a8c7ade86380d756193d1755b047cf91613603d00c5fe9679ee6'
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 3

user_objects:list = []





#---------------------------------------------------------
conn = psycopg2.connect(database="Discord",host="localhost", user="postgres", password="admin", port="5432")
cursor = conn.cursor()
            # General Functions
# Get next id
def next_id(table_name:str) -> int:
    cursor.execute(f"select * from {table_name} limit 0")
    id_column_name = cursor.description[0][0]
    command = f'select max({id_column_name}) from {table_name}'
    cursor.execute(command)
    return (cursor.fetchone()[0] + 1)
    
# Close the connections at exit 
def close_conn():
    conn.close()
    cursor.close()

# Get user_id by username
def get_user_id(username: str):
    command = f"select user_id from \"user\" where username = '{username}'"
    cursor.execute(command)
    return cursor.fetchone()[0]

            # BASE MODELS HERE

# Remove later ---------------------------------------------------
class User(BaseModel):
    password:str
    phone_number:str | None = None
    email:str | None = None
    join_date:date | None = None
    username:str
    display_name:str | None = None
    status_id:int | None = None


class UserInDB(User):
    hashed_password: str
 
class Token(BaseModel):
    access_token: str
    token_type: str


class TokenData(BaseModel):
    username: str | None = None

class User_modable_col(str, Enum):
    display_name = "display_name"
    phone_number = "phone_number"
    email = "email"

class Left_from(str, Enum):
    group = "group_member"
    server = "server_member"
    
    
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

#-----------------------------------------------------------------




            # FUNCTIONS HERE 
# Register user
def register_user(User: User): 
    id = next_id('"user"')
    command = f"insert into \"user\" values ({id}, '{get_password_hash(User.password)}', '{User.phone_number}', '{User.email}', '{str(User.join_date)}', '{User.username}', '{User.display_name}', {str(User.status_id)})"
    
    cursor.execute(command)
    conn.commit()

# Delete user
def delete_user(user: User):
    try:
        command = f"delete from \"user\" where \"user\".username = '{user.username}'"
        cursor.execute(command)
        conn.commit()
        return True
    except Exception:
        return False
 
# Update user
def update_user_info(username, column_name, new_value):
    try:
        command = f"update \"user\" set {column_name} = '{new_value}' where username = '{username}'"
        cursor.execute(command)
        conn.commit()
        return True
    except Exception:
        return False

# Add user to group
def add_member_group(username:str, group_id: int):
    user_id = get_user_id(username)
    command = f"insert into group_member values({user_id}, {group_id})"
    cursor.execute(command)
    conn.commit()

# Create Server
def create_server(username:str, server_name:str):
    user_id = get_user_id(username)
    server_id = next_id("server")
    command = f"insert into server values ({server_id}, {user_id}, '{server_name}', now())"
    cursor.execute(command)
    conn.commit()
    return True

# Add Friend
def add_friend(username1, username2):
    user_id_1 = get_user_id(username1)
    user_id_2 = get_user_id(username2)
    command = f"insert into friend values ({user_id_1}, {user_id_2})"
    cursor.execute(command)
    conn.commit()
    return True

# Create Event
def create_event(server_id:int, location:str, topic:str, start_date:date, end_date:date, description:str, creator_username):
    creator_id = get_user_id(creator_username)
    event_id = next_id("event")
    command = f"insert into event values ({event_id}, {server_id}, '{location}', '{topic}', '{str(start_date)}', '{str(end_date)}', '{description}', {creator_id})"
    cursor.execute(command)
    conn.commit()
    return True

# Left from group or server
def left(username:str, table_name:str, ID:int):
    if table_name == Left_from.server:
        command = f"delete from {table_name} where member_id = {get_user_id(username)} and server_id = {ID}"
    else:
        command = f"delete from {table_name} where member_id = {get_user_id(username)} and group_id = {ID}"
    cursor.execute(command)
    conn.commit()
    return True


# Get User Object by username
def get_user(username: str):
    command = f"select * from \"user\" where username = '{username}'"
    cursor.execute(command)
    user_tuple = cursor.fetchone()
    if user_tuple is None:
        return None
    else:
        print(user_tuple)
        user = User(password=user_tuple[1], phone_number=user_tuple[2], email=user_tuple[3], join_date=user_tuple[4], username=user_tuple[5], display_name=user_tuple[6], status_id=int(user_tuple[7]))
        return user

    
def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def authenticate_user(username: str, password: str):
    user = get_user(username)
    if not user:
        return False
    if not verify_password(password, user.password):
        return False
    return user 

def create_access_token(data: dict, expires_delta: timedelta | None = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt



#---------------------------------------------------



# Start
app = FastAPI()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")
   
async def get_current_user(token: Annotated[str, Depends(oauth2_scheme)]):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = TokenData(username=username)
    except InvalidTokenError:
        raise credentials_exception
    user = get_user(username=token_data.username)
    if user is None:
        raise credentials_exception
    return user
# ----------------------------------GENERAL-----------------------------------

# Login
@app.post("/token")
async def login_for_access_token(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
) -> Token:
    user = authenticate_user(form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    return Token(access_token=access_token, token_type="bearer")

# Get user info
@app.get("/users/me")
async def read_users_me(
    current_user: Annotated[User, Depends(get_current_user)],
):
    return current_user

# User Registration
@app.post("/register_user")
async def REGISTER_USER(user: User):
    register_user(user)
    return 'user added successfully'
# Delete User's Account
@app.delete("/delete_user")
async def DELETE_USER(current_user: Annotated[User, Depends(get_current_user)], password:str = ""):
    if verify_password(password, current_user.password):
        return delete_user(current_user)
    else: 
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect password"
        )

# Update User Info
@app.patch("/update_user_info")
async def UPDATE_USER_INFO(current_user: Annotated[User, Depends(get_current_user)], password:str = "", column_name:User_modable_col = "display_name", new_val:str = ""):
    if verify_password(password, current_user.password):
        return update_user_info(current_user.username, column_name, new_val)
    else: 
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect password"
        )

# ----------------------------------DISCORD-----------------------------------
# Add current user to group
@app.post("/add_member_group")
async def ADD_MEMBER_GROUP(current_user: Annotated[User, Depends(get_current_user)], group_id: int = 0):
    try:
        add_member_group(current_user.username, group_id)
        return True
    except Exception as e:
        print(e)
        return "something went wrong. perhaps user deleted their accoutn?"

# Create Server
@app.post("/create_server")
async def CREATE_SERVER(current_user: Annotated[User, Depends(get_current_user)], server_name:str = ""):
    try:
        return create_server(current_user.username, server_name)
    except Exception as e:
        print(e)
        return "create server failure."

# Add Friend
@app.post("/add_friend")
async def ADD_FRIEND(current_user: Annotated[User, Depends(get_current_user)], friend_username:str = ""):
    try:
        if get_user(friend_username):
            return add_friend(current_user.username, friend_username)
        else:
            return "username is invalid"
    except Exception as e:
        print(e)
        return "add friend failure"
        
# Create Event
@app.post("/create_event")
async def CREATE_EVENT(current_user: Annotated[User, Depends(get_current_user)], server_id:int = -1, location:str = "", topic:str = "", start_date:date = date.today(), end_date:date = date.today(), description:str = ""):
    try:
        return create_event(server_id, location, topic, start_date, end_date, description, current_user.username)
    except Exception as e:
        print(e)
        return "create event failure"

# Remove user
@app.post("/left_from")
async def LEFT(current_user: Annotated[User, Depends(get_current_user)], table:Left_from = Left_from.group, ID:int = -1):
    try:
        return left(current_user.username, table, ID)
    except Exception as e:
        print(e)
        return False



atexit.register(close_conn)