#!/bin/bash

# 主菜单
function main_menu {
    clear
    echo "Menu"
    echo "1) Configure PyPI Mirror"
    echo "2) Configure npm Mirror"
    echo "3) Install&Update docker-ce"
    echo "5) exit"
    read -p "Please select an option: " choice

    case $choice in
        1) option_pypi_menu ;;
        2) option_npm_menu ;;
        3) option_update_docker_ce_menu ;;
        5) exit 0 ;;
        *) echo "Invalid option, please try again." ; main_menu ;;
    esac
}

# 选项 pypi 的二级菜单
function option_pypi_menu {
    # 获取当前的 PyPI 镜像源
    PYPI_MIRROR=$(pip config get global.index-url)
    clear
    # 检查是否成功获取到镜像源
    if [ -z "$PYPI_MIRROR" ]; then
        echo "No global PyPI mirror is currently set; using the default PyPI source."
    else
        echo "The current PyPI mirror is: : $PYPI_MIRROR"
    fi
        
    echo "1) Choose Tsinghua Mirror"
    echo "2) Choose Aliyun Mirror"
    echo "3) Restore default mirror"
    echo "4) Return to Menu"
    read -p "Please select an option: " choice

    case $choice in
        1) echo "Choose Tsinghua Mirror" ; set_pypi_mirror "https://pypi.tuna.tsinghua.edu.cn/simple/"; option_pypi_menu ;;
        2) echo "Choose Aliyun Mirror" ;  set_pypi_mirror "https://mirrors.aliyun.com/pypi/simple/"; option_pypi_menu ;;
        3) echo "Restore default mirror" ;  set_pypi_mirror "https://pypi.org/simple"; option_pypi_menu ;;
        4) main_menu ;;
        *) echo "Invalid option, please try again." ; option_pypi_menu ;;
    esac
}

function set_pypi_mirror {
    # 获取传递的参数
    local MIRROR_URL=$1
    # 定义要执行的命令
    COMMAND="pip config set global.index-url $MIRROR_URL"
    # 打印命令
    echo "Command to be executed: $COMMAND"
    # 执行命令
    eval $COMMAND

    # 升级 pip
    echo "Upgrading pip..."
    python -m pip install --upgrade pip
}


function option_npm_menu {
    # 获取当前的 PyPI 镜像源
    NPM_MIRROR=$(npm config get registry)
    clear
    # 检查是否成功获取到镜像源
    if [ -z "$NPM_MIRROR" ]; then
        echo "No global npm mirror is currently set; using the default npm source."
    else
        echo "The current npm mirror is: : $NPM_MIRROR"
    fi

        
    echo "1) Choose npmmirror Mirror"
    echo "2) Restore default Mirror"
    echo "3) Return to Menu"
    read -p "Please select an option: " choice

    case $choice in
        1) echo "Choose npmmirror Mirror" ; npm config set registry https://registry.npmmirror.com; option_npm_menu ;;
        2) echo "Choose default Mirror" ; npm config set registry https://registry.npmjs.org; option_npm_menu ;;
        3) main_menu ;;
        *) echo "Invalid option, please try again." ; option_npm_menu ;;
    esac
}

function auth_root {
    # 检查是否以 root 用户身份运行
    if [ "$EUID" -ne 0 ]; then
        echo "Error: This script requires superuser privileges."
        echo "Please run this script with 'sudo' or as the root user."

        # Use sudo to verify the user
        if sudo -v; then
            echo "Verification successful, continuing to execute the script..."
        else
            echo "Verification failed, exiting the script."
            exit 1
        fi
    fi
}

# 选项 B 的二级菜单
function option_update_docker_ce_menu {
    clear
    echo "Docker Menu"
    echo "1) Install & update docker-ce"
    echo "2) set docker hub Mirror"
    echo "3) set docker server proxy"
    echo "4) remove docker server proxy"
    echo "5) return main menu"
    read -p "Please select an option: " choice

    case $choice in
        1) echo "Install & update docker-ce" ; update_docker_ce ; option_update_docker_ce_menu;;
        2) echo "set docker hub Mirror" ; setup_docker_hub_mirror ; option_update_docker_ce_menu;;
        3) echo "set docker server proxy" ; setup_docker_server_proxy ; option_update_docker_ce_menu;;
        4) echo "remove docker server proxy" ; remove_docker_server_proxy ; option_update_docker_ce_menu;;
        5) main_menu ;;
        *) echo "Verification failed, exiting the script." ; option_update_docker_ce_menu ;;
    esac
}

function update_docker_ce { 
    auth_root ;
    # https://mirrors.tuna.tsinghua.edu.cn/help/docker-ce/
    export DOWNLOAD_URL="https://mirrors.tuna.tsinghua.edu.cn/docker-ce"
    curl -fsSL https://raw.githubusercontent.com/docker/docker-install/master/install.sh | sh
}

function setup_docker_hub_mirror {
    auth_root ;
    # 获取当前日期和时间
    datetime=$(date +"%Y%m%d_%H%M%S")

    # 要写入的内容
    new_content='{
    "registry-mirrors": [
            "https://docker.m.daocloud.io",
            "https://dockerproxy.com",
            "https://docker.mirrors.ustc.edu.cn",
            "https://docker.nju.edu.cn"
            ],
    "log-driver": "json-file",
    "log-opts": {"max-size": "50m", "max-file": "3"}
    }'

    # Check if /etc/docker/daemon.json exists
    if [ -f /etc/docker/daemon.json ]; then
        # Backup the existing file
        sudo cp /etc/docker/daemon.json /etc/docker/daemon.json_$datetime
        echo "Backed up the existing daemon.json to /etc/docker/daemon.json_$datetime"
    fi

    # Write new content to /etc/docker/daemon.json
    echo "$new_content" | sudo tee /etc/docker/daemon.json > /dev/null

    echo "New daemon.json has been written to /etc/docker/daemon.json"
    sudo systemctl daemon-reload
    sudo systemctl restart docker
}


function setup_docker_server_proxy {
    auth_root ;
    # 获取当前日期和时间
    read -p "Please input proxy(format：socks5://user:pass@127.0.0.1:1080, http://127.0.0.1:1080/): " PROXY

    # 创建配置文件目录
    sudo mkdir -p /etc/systemd/system/docker.service.d

    # 创建并写入配置文件
    cat <<EOL | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=${PROXY}"
Environment="HTTPS_PROXY=${PROXY}"
EOL

    # 重启 Docker 服务
    sudo systemctl daemon-reload
    sudo systemctl restart docker

    # 查看 Docker 的环境变量
    sudo systemctl show --property=Environment docker
}


function remove_docker_server_proxy {
    # 配置文件路径
CONFIG_FILE="/etc/systemd/system/docker.service.d/http-proxy.conf"

# 判断文件是否存在
if [ -f "$CONFIG_FILE" ]; then
    sudo rm -f "$CONFIG_FILE"
    # 重启 Docker 服务
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    # 查看 Docker 的环境变量
    sudo systemctl show --property=Environment docker
else
    echo "don't find http-proxy.conf"
fi

}



# 启动主菜单
main_menu