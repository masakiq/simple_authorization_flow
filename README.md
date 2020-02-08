## set env

```sh
export SAF_AUTH_CODE=abc
export AUTH_TOKEN=xyz
export AUTH_URI=http://localhost:5001
export AUTH_USER_INFO=hogeta_fugazou
export CLIENT_ID=123
export CLIENT_URI=http://localhost:5000
export RESOURCE_URI=http://localhost:5002
export SOCIAL_URI=http://localhost:5003
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
