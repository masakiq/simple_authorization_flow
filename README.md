## set env

### Client ID & User Info

```sh
export SAF_CLIENT_ID=123
export SAF_USER_SUB=hogeta_fugazou
```

### Redirect URI

```sh
# for general
export SAF_REDIRECT_URI=http://localhost:5000/callback
# for social
export SAF_REDIRECT_URI=http://localhost:5003/callback
```

### Server URI

```sh
export SAF_CLIENT_SERVER_URI=http://localhost:5000
export SAF_AUTH_SERVER_URI=http://localhost:5001
export SAF_RESOURCE_SERVER_URI=http://localhost:5002
export SAF_SOCIAL_SERVER_URI=http://localhost:5003
```

## start

### auth server

```sh
bin/auth_server
```

### open_id_connect server

```sh
bin/open_id_server
```

### general auth client

```sh
bin/general/auth_client
```

### general open_id_connect client

```sh
bin/general/open_id_client
```

### social auth client

```sh
bin/social/auth_client
```

### social open_id_connect client

```sh
bin/social/open_id_client
```

## kill servers

```sh
bin/kill_servers
```

## tree

```sh
tree -a -I '.git'
```
