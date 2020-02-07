## set env

```sh
source .env
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
