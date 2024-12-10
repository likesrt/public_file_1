#!/bin/bash

# 检查是否传入参数
if [ "$#" -lt 4 ]; then
    echo "Usage: $0 <AccessKey> <SecretKey> <Domain1> <Domain2> ..."
    exit 1
fi

# 从脚本参数中读取 AccessKey 和 SecretKey
ACCESS_KEY="$1"
SECRET_KEY="$2"

# 从脚本参数中读取域名列表
DOMAINS=("${@:3}")

# 证书路径
FULLCHAIN_PATH="./fullchain.pem"
PRIVKEY_PATH="./privkey.pem"

# 证书备注名
CURRENT_DATE=$(date +"%y/%m/%d")
NOTE="Certificate $CURRENT_DATE"

# 生成AccessToken
function generateAccessToken() {
    local apiPath="$1"
    local body="$2"
    local signStr=$(echo -e "${apiPath}\n${body}")
    local sign=$(echo -n "$signStr" | openssl dgst -sha1 -hmac "$SECRET_KEY" | awk '{print $NF}')
    local accessToken="$ACCESS_KEY:$sign"

    echo "$accessToken"
}

# 上传证书到多吉云
function uploadCert() {
    local note="$1"
    local certFile="$2"
    local privateKeyFile="$3"
    local certContent=$(<"$certFile")
    local privateKeyContent=$(<"$privateKeyFile")
    local encodedCert=$(echo "$certContent" | jq -sRr @uri)
    local encodedPrivateKey=$(echo "$privateKeyContent" | jq -sRr @uri)
    local body="note=$note&cert=$encodedCert&private=$encodedPrivateKey"
    local accessToken=$(generateAccessToken "/cdn/cert/upload.json" "$body")
    local response=$(curl -s -X POST "https://api.dogecloud.com/cdn/cert/upload.json"  \
         -H "Authorization: TOKEN $accessToken" \
         -H "Content-Type: application/x-www-form-urlencoded" \
         --data "$body")

    local code=$(echo "$response" | jq -r '.code')

    if [ "$code" -eq 200 ]; then
        echo "证书上传成功！"
        local certId=$(echo "$response" | jq -r '.data.id')
        echo "证书ID：$certId"
        bindCert "$certId"
    else
        local errMsg=$(echo "$response" | jq -r '.msg')
        echo "证书上传失败，错误代码：$code，错误信息：$errMsg"
    fi
}

# 绑定证书到域名
function bindCert() {
    local certId="$1"
    local responses=()

    for domain in "${DOMAINS[@]}"; do
        (
            local body="id=$certId&domain=$domain"
            local accessToken=$(generateAccessToken "/cdn/cert/bind.json" "$body")
            local response=$(curl -s -X POST "https://api.dogecloud.com/cdn/cert/bind.json"  \
                 -H "Authorization: TOKEN $accessToken" \
                 -H "Content-Type: application/x-www-form-urlencoded" \
                 --data "$body")
            local code=$(echo "$response" | jq -r '.code')

            if [ "$code" -eq 200 ]; then
                echo "证书已成功绑定到 $domain"
            else
                local errMsg=$(echo "$response" | jq -r '.msg')
                echo "绑定证书到 $domain 失败，错误代码：$code，错误信息：$errMsg"
            fi
        ) &
    done

    wait
}

# 上传证书并绑定到域名
uploadCert "$NOTE" "$FULLCHAIN_PATH" "$PRIVKEY_PATH"
