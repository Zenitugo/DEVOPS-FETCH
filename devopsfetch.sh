#!/bin/bash

# Create the DevOpsFetch script



# Function to display help
devopsfetch_help() {
    echo "Usage: devopsfetch [OPTION]..."
    echo "Retrieve and display system information for DevOps purposes."
    echo
    echo "Options:"
    echo "  -p, --port [PORT_Number]    Display active ports or info about a specific port"
    echo "  -d, --docker [CONTAINER_NAME]  Display Docker images/containers or info about a specific container"
    echo "  -n, --nginx [DOMAIN] Display Nginx domains or info about a specific domain"
    echo "  -u, --users [USER]   Display user logins or info about a specific user"
    echo "  -t, --time [start-date][end-date]     Display activities within a specified time range "
    echo "  -h, --help           Display this help message"
    echo
    echo "For more information, see the full documentation."
    echo "Example: devopsfetch -p 80"
    echo "         devopsfetch -d nginx"
    echo "         devopsfetch -n example.com"
    echo "         devopsfetch -u john"
    echo "         devopsfetch -t '2024-07-22'"
}

# Function to display active ports
ports_available() {
    if [ -z "$1" ]; then
        printf "%-15s %-5s %-8s\n" "USER" "PORT" "SERVICE"
        sudo lsof -i -P -n | grep LISTEN | awk '{
            port = $9
            sub(/.*:/, "", port)
            user = $3
            service = $1
            if (length(service) > 8) service = substr(service, 1, 8)
            printf "%-15s %-5s %-8s\n", user, port, service
        }' | sort -k2 -n | uniq  
   else
        echo "Information for port $1:"
        printf "%-15s %-5s %-8s\n" "USER" "PORT" "SERVICE"
        result=$(sudo lsof -i :$1 -P -n | grep LISTEN | awk '{
            port = $9
            sub(/.*:/, "", port)
            user = $3
            service = $1
            if (length(service) > 8) service = substr(service, 1, 8)
            printf "%-15s %-5s %-8s\n", user, port, service
        }')
        if [ -z "$result" ]; then
            echo "No Service found on Port found $1"
        else
            echo "$result"
        fi
    fi
}


# Function to display Docker information
docker_info() {
    if [ -z "$1" ]; then
        echo "Docker images:"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}"
        echo
        echo "Docker containers:"
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.ID}}\t{{.Status}}"
    else
        echo "Information for Docker container $1:"
        docker inspect $1
    fi
}



# Function to display Nginx information
nginx_server_info() {
    if [ -z "$1" ]; then
        printf "%-30s %-30s %-30s %-50s\n" "DOMAIN" "PROXY" "CONFIGURATION" "CONFIG FILE"
        printf "%-30s %-30s %-30s %-50s\n" "------" "-----" "-------------" "-----------"
        
        for config in /etc/nginx/sites-enabled/*; do
            if [ -f "$config" ]; then
                domain=$(grep -m1 "server_name" "$config" | awk '{print $2}' | sed 's/;$//')
                proxy=$(grep -m1 "proxy_pass" "$config" | awk '{print $2}' | sed 's/;$//')
                listen=$(grep -m1 "listen" "$config" | awk '{print $2}' | sed 's/;$//')
                root=$(grep -m1 "root" "$config" | awk '{print $2}' | sed 's/;$//')
                
                config_info="listen: $listen"
                [ ! -z "$root" ] && config_info="$config_info, root: $root"
                
                printf "%-30s %-30s %-30s %-50s\n" "$domain" "${proxy:-N/A}" "$config_info" "$config"
            fi
        done
    else
        echo "Nginx configuration for domain $1:"
        grep -A 20 -R "server_name $1" /etc/nginx/sites-enabled/* | sed -n '/server_name/,$p'
    fi
}
  


# Function to display user information
get_users() {
    if [ -z "$1" ]; then
        # Display all regular users
        printf "%-15s %-10s %s\n" "Users" "Status" "Last-Login"
        echo "-----------------------------------------------"
    
        awk -F: '$3 >= 1000 { print $1 }' /etc/passwd | while read user; do
            status="Regular"
        
            last_login=$(last -n 1 "$user" | head -n 1 | awk '{print $4, $5, $6, $7, $8, $9}')
            if [[ -n "$last_login" ]]; then
                printf "%-15s %-10s %s\n" "$user" "$status" "$last_login"
            else
                printf "%-15s %-10s %s\n" "$user" "$status" "Never logged in"
            fi
        done
    else
        # Display details for a specific user
        if id "$1" &>/dev/null; then
            printf "%-10s %-10s %-20s %-20s\n" "UID" "GID" "Groups" "Last-Login"
            echo "-------------------------------------------------------------------------"
        
            uid=$(id -u "$1")
            gid=$(id -g "$1")
            groups=$(id -Gn "$1" | tr ' ' '\n')
            last_login=$(last -n 1 "$1" | head -n 1 | awk '{print $4, $5, $6, $7, $8, $9}')
            if [[ -z "$last_login" ]]; then
                last_login="Never logged in"
            fi
        
            printf "%-10s %-10s %-20s %-20s\n" "$uid" "$gid" "$(echo "$groups" | head -n1)" "$last_login"
            echo "$groups" | tail -n +2 | sed 's/^/                    /'
        else
            echo "User $1 does not exist."
        fi
    fi
}


# Function to filter system logs based on time range
filter_logs() {
    local start_date="$1"
    local end_date="$2"
    
    # If only one date is provided, set end_date to current date
    if [ -z "$end_date" ]; then
        end_date=$(date +"%Y-%m-%d")
    fi
    
    # Convert dates to the format journalctl expects
    local start_time="${start_date} 00:00:00"
    local end_time="${end_date} 23:59:59"

    echo "Displaying system logs from $start_time to $end_time"
    
    # Use journalctl to display logs within the specified time range
    journalctl --since "$start_time" --until "$end_time"
    
    # Check if journalctl command was successful
    if [ $? -ne 0 ]; then
        echo "Error occurred while fetching logs."
        echo "Available log range:"
        journalctl --list-boots
    fi
}


# Main script logic
case "$1" in
    -p|--port)
        ports_available "$2"
        ;;
    -d|--docker)
        docker_info "$2"
        ;;
    -n|--nginx)
        nginx_server_info "$2"
        ;;
    -u|--users)
        display_users "$2"
        ;;
    -t|--time)
        if [ -z "$2" ]; then
            echo "Please specify at least a start date (YYYY-MM-DD)"
        else
            filter_logs "$2" "$3"
        fi
        ;;
    -h|--help)
        devopsfetch_help
        ;;
    *)
        echo "Invalid option. Use -h or --help for usage information."
        ;;
esac