## set env

```sh
export SAF_AUTH_CODE=abc
export SAF_AUTH_TOKEN=xyz
export SAF_AUTH_SERVER_URI=http://localhost:5001
export SAF_USER_SUB=hogeta_fugazou
export SAF_CLIENT_ID=123
export SAF_CLIENT_SERVER_URI=http://localhost:5000
export SAF_RESOURCE_SERVER_URI=http://localhost:5002
export SAF_SOCIAL_SERVER_URI=http://localhost:5003
```

## start

* for fish
```sh
for i in (find ./* -name '*.rb'); nohup ruby $i & ;end
```

## print pids

```sh
ps aux | grep ruby | grep -v grep | awk '{print $2}'
```

## kill pids

```sh
ps aux | grep ruby | grep -v grep | awk '{printf("%s ",$2); system("kill " $2)}'
```

## rm nohup.out

```sh
rm -rf */**/*.out
```

## tree

```sh
tree -a -I '.git'
```
