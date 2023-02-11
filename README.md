# socat-static
* Statically compiled socat with musl
## To get started:
* **Download the latest revision**
```
git clone https://github.com/VHSgunzo/socat-static.git
```
* **Build**
```
cd socat-static
docker build -t socat-static .

docker run -v $PWD:/output --rm socat-static
# OR without OpenSSL:
docker run -e NO_OPENSSL=1 -v $PWD:/output --rm socat-static

docker image rm socat-static
```
