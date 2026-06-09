#!/bin/bash

# ============================================================
#  User & Group Manager — whiptail TUI
#  Requirements: bash, whiptail, sudo/root
# ============================================================

TITLE="User & Group Manager"

# ---------- helper: check root ----------
check_root() {
    if [[ $EUID -ne 0 ]]; then
        whiptail --title "Permission Error" --msgbox \
            "This program must be run as root.\nPlease run: sudo $0" 8 50
        exit 1
    fi
}

# ============================================================
#  USER FUNCTIONS
# ============================================================

add_user() {
    USERNAME=$(whiptail --title "$TITLE" --inputbox \
        "Enter new username:" 8 50 3>&1 1>&2 2>&3)
    [[ $? -ne 0 || -z "$USERNAME" ]] && return

    # Check if user already exists
    if id "$USERNAME" &>/dev/null; then
        whiptail --title "Error" --msgbox "User '$USERNAME' already exists!" 8 50
        return
    fi

    PASSWORD=$(whiptail --title "$TITLE" --passwordbox \
        "Enter password for '$USERNAME':" 8 50 3>&1 1>&2 2>&3)
    [[ $? -ne 0 ]] && return

    FULLNAME=$(whiptail --title "$TITLE" --inputbox \
        "Enter full name (optional):" 8 50 3>&1 1>&2 2>&3)

    # Create user
    if useradd -m -c "$FULLNAME" "$USERNAME" 2>/dev/null; then
        echo "$USERNAME:$PASSWORD" | chpasswd
        whiptail --title "Success" --msgbox \
            "User '$USERNAME' created successfully!" 8 50
    else
        whiptail --title "Error" --msgbox \
            "Failed to create user '$USERNAME'." 8 50
    fi
}

modify_user() {
    # Build user list
    USERS=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1 " " $5}' /etc/passwd)
    if [[ -z "$USERS" ]]; then
        whiptail --title "Info" --msgbox "No regular users found." 8 50
        return
    fi

    # Build whiptail menu entries
    MENU_ITEMS=()
    while IFS=" " read -r user comment; do
        MENU_ITEMS+=("$user" "${comment:-No description}")
    done <<< "$USERS"

    USERNAME=$(whiptail --title "$TITLE" --menu \
        "Select user to modify:" 20 60 10 \
        "${MENU_ITEMS[@]}" 3>&1 1>&2 2>&3)
    [[ $? -ne 0 || -z "$USERNAME" ]] && return

    ACTION=$(whiptail --title "$TITLE" --menu \
        "What to modify for '$USERNAME'?" 15 60 5 \
        "1" "Change full name" \
        "2" "Change password" \
        "3" "Change shell" \
        "4" "Add to group" \
        3>&1 1>&2 2>&3)
    [[ $? -ne 0 ]] && return

    case $ACTION in
        1)
            NEWNAME=$(whiptail --title "$TITLE" --inputbox \
                "Enter new full name:" 8 50 3>&1 1>&2 2>&3)
            [[ $? -ne 0 ]] && return
            usermod -c "$NEWNAME" "$USERNAME"
            whiptail --title "Success" --msgbox "Full name updated." 8 50
            ;;
        2)
            NEWPASS=$(whiptail --title "$TITLE" --passwordbox \
                "Enter new password:" 8 50 3>&1 1>&2 2>&3)
            [[ $? -ne 0 ]] && return
            echo "$USERNAME:$NEWPASS" | chpasswd
            whiptail --title "Success" --msgbox "Password changed." 8 50
            ;;
        3)
            NEWSHELL=$(whiptail --title "$TITLE" --inputbox \
                "Enter new shell (e.g. /bin/bash):" 8 50 "/bin/bash" \
                3>&1 1>&2 2>&3)
            [[ $? -ne 0 ]] && return
            usermod -s "$NEWSHELL" "$USERNAME"
            whiptail --title "Success" --msgbox "Shell updated to $NEWSHELL." 8 50
            ;;
        4)
            GROUPNAME=$(whiptail --title "$TITLE" --inputbox \
                "Enter group name to add '$USERNAME' to:" 8 50 \
                3>&1 1>&2 2>&3)
            [[ $? -ne 0 ]] && return
            if usermod -aG "$GROUPNAME" "$USERNAME" 2>/dev/null; then
                whiptail --title "Success" --msgbox \
                    "'$USERNAME' added to group '$GROUPNAME'." 8 50
            else
                whiptail --title "Error" --msgbox \
                    "Group '$GROUPNAME' does not exist." 8 50
            fi
            ;;
    esac
}

delete_user() {
    USERS=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1 " " $5}' /etc/passwd)
    if [[ -z "$USERS" ]]; then
        whiptail --title "Info" --msgbox "No regular users found." 8 50
        return
    fi

    MENU_ITEMS=()
    while IFS=" " read -r user comment; do
        MENU_ITEMS+=("$user" "${comment:-No description}")
    done <<< "$USERS"

    USERNAME=$(whiptail --title "$TITLE" --menu \
        "Select user to DELETE:" 20 60 10 \
        "${MENU_ITEMS[@]}" 3>&1 1>&2 2>&3)
    [[ $? -ne 0 || -z "$USERNAME" ]] && return

    REMOVE_HOME=$(whiptail --title "$TITLE" --yesno \
        "Delete home directory for '$USERNAME' too?" 8 50 3>&1 1>&2 2>&3; echo $?)

    if whiptail --title "Confirm" --yesno \
        "Are you sure you want to delete user '$USERNAME'?" 8 60; then
        if [[ $REMOVE_HOME -eq 0 ]]; then
            userdel -r "$USERNAME" 2>/dev/null
        else
            userdel "$USERNAME" 2>/dev/null
        fi
        whiptail --title "Success" --msgbox "User '$USERNAME' deleted." 8 50
    fi
}

list_users() {
    USER_LIST=$(awk -F: '$3 >= 1000 && $1 != "nobody" {
        printf "%-15s UID:%-6s Shell: %s\n", $1, $3, $7
    }' /etc/passwd)

    if [[ -z "$USER_LIST" ]]; then
        USER_LIST="No regular users found."
    fi

    whiptail --title "All Users" --scrolltext --msgbox "$USER_LIST" 20 70
}

disable_user() {
    USERS=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1 " " $5}' /etc/passwd)
    [[ -z "$USERS" ]] && { whiptail --title "Info" --msgbox "No users found." 8 50; return; }

    MENU_ITEMS=()
    while IFS=" " read -r user comment; do
        MENU_ITEMS+=("$user" "${comment:-No description}")
    done <<< "$USERS"

    USERNAME=$(whiptail --title "$TITLE" --menu \
        "Select user to LOCK:" 20 60 10 \
        "${MENU_ITEMS[@]}" 3>&1 1>&2 2>&3)
    [[ $? -ne 0 || -z "$USERNAME" ]] && return

    passwd -l "$USERNAME" &>/dev/null
    usermod --expiredate 1 "$USERNAME" &>/dev/null
    whiptail --title "Success" --msgbox "User '$USERNAME' has been LOCKED." 8 50
}

enable_user() {
    USERS=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1 " " $5}' /etc/passwd)
    [[ -z "$USERS" ]] && { whiptail --title "Info" --msgbox "No users found." 8 50; return; }

    MENU_ITEMS=()
    while IFS=" " read -r user comment; do
        MENU_ITEMS+=("$user" "${comment:-No description}")
    done <<< "$USERS"

    USERNAME=$(whiptail --title "$TITLE" --menu \
        "Select user to UNLOCK:" 20 60 10 \
        "${MENU_ITEMS[@]}" 3>&1 1>&2 2>&3)
    [[ $? -ne 0 || -z "$USERNAME" ]] && return

    passwd -u "$USERNAME" &>/dev/null
    usermod --expiredate "" "$USERNAME" &>/dev/null
    whiptail --title "Success" --msgbox "User '$USERNAME' has been UNLOCKED." 8 50
}

change_password() {
    USERS=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1 " " $5}' /etc/passwd)
    [[ -z "$USERS" ]] && { whiptail --title "Info" --msgbox "No users found." 8 50; return; }

    MENU_ITEMS=()
    while IFS=" " read -r user comment; do
        MENU_ITEMS+=("$user" "${comment:-No description}")
    done <<< "$USERS"

    USERNAME=$(whiptail --title "$TITLE" --menu \
        "Select user to change password:" 20 60 10 \
        "${MENU_ITEMS[@]}" 3>&1 1>&2 2>&3)
    [[ $? -ne 0 || -z "$USERNAME" ]] && return

    NEWPASS=$(whiptail --title "$TITLE" --passwordbox \
        "Enter new password for '$USERNAME':" 8 50 3>&1 1>&2 2>&3)
    [[ $? -ne 0 ]] && return

    CONFIRM=$(whiptail --title "$TITLE" --passwordbox \
        "Confirm new password:" 8 50 3>&1 1>&2 2>&3)
    [[ $? -ne 0 ]] && return

    if [[ "$NEWPASS" != "$CONFIRM" ]]; then
        whiptail --title "Error" --msgbox "Passwords do not match!" 8 50
        return
    fi

    echo "$USERNAME:$NEWPASS" | chpasswd
    whiptail --title "Success" --msgbox "Password for '$USERNAME' changed." 8 50
}

# ============================================================
#  GROUP FUNCTIONS
# ============================================================

add_group() {
    GROUPNAME=$(whiptail --title "$TITLE" --inputbox \
        "Enter new group name:" 8 50 3>&1 1>&2 2>&3)
    [[ $? -ne 0 || -z "$GROUPNAME" ]] && return

    if getent group "$GROUPNAME" &>/dev/null; then
        whiptail --title "Error" --msgbox "Group '$GROUPNAME' already exists!" 8 50
        return
    fi

    if groupadd "$GROUPNAME" 2>/dev/null; then
        whiptail --title "Success" --msgbox "Group '$GROUPNAME' created." 8 50
    else
        whiptail --title "Error" --msgbox "Failed to create group." 8 50
    fi
}

modify_group() {
    GROUPS=$(awk -F: '$3 >= 100 && $1 !~ /^(root|daemon|bin|sys|adm|tty|disk|lp|mail|news|uucp|man|proxy|kmem|dialout|fax|voice|cdrom|floppy|tape|sudo|audio|dip|www-data|backup|operator|list|irc|src|shadow|utmp|video|sasl|plugdev|staff|games|users|nogroup|input|kvm|render|crontab|syslog|messagebus|systemd|netdev|lxd|docker|ssl-cert|ssh)$/ {print $1 " GID:" $3}' /etc/group)
    [[ -z "$GROUPS" ]] && { whiptail --title "Info" --msgbox "No groups found." 8 50; return; }

    MENU_ITEMS=()
    while read -r gname gid; do
        MENU_ITEMS+=("$gname" "$gid")
    done <<< "$GROUPS"

    GROUPNAME=$(whiptail --title "$TITLE" --menu \
        "Select group to modify:" 20 60 10 \
        "${MENU_ITEMS[@]}" 3>&1 1>&2 2>&3)
    [[ $? -ne 0 || -z "$GROUPNAME" ]] && return

    ACTION=$(whiptail --title "$TITLE" --menu \
        "Action for group '$GROUPNAME':" 12 60 3 \
        "1" "Rename group" \
        "2" "Add member" \
        "3" "Remove member" \
        3>&1 1>&2 2>&3)
    [[ $? -ne 0 ]] && return

    case $ACTION in
        1)
            NEWNAME=$(whiptail --title "$TITLE" --inputbox \
                "Enter new name for '$GROUPNAME':" 8 50 3>&1 1>&2 2>&3)
            [[ $? -ne 0 ]] && return
            groupmod -n "$NEWNAME" "$GROUPNAME"
            whiptail --title "Success" --msgbox "Group renamed to '$NEWNAME'." 8 50
            ;;
        2)
            MEMBER=$(whiptail --title "$TITLE" --inputbox \
                "Enter username to add:" 8 50 3>&1 1>&2 2>&3)
            [[ $? -ne 0 ]] && return
            if usermod -aG "$GROUPNAME" "$MEMBER" 2>/dev/null; then
                whiptail --title "Success" --msgbox "'$MEMBER' added to '$GROUPNAME'." 8 50
            else
                whiptail --title "Error" --msgbox "User '$MEMBER' not found." 8 50
            fi
            ;;
        3)
            MEMBER=$(whiptail --title "$TITLE" --inputbox \
                "Enter username to remove:" 8 50 3>&1 1>&2 2>&3)
            [[ $? -ne 0 ]] && return
            gpasswd -d "$MEMBER" "$GROUPNAME" &>/dev/null
            whiptail --title "Success" --msgbox "'$MEMBER' removed from '$GROUPNAME'." 8 50
            ;;
    esac
}

delete_group() {
    GROUPS=$(awk -F: '$3 >= 100 && $1 !~ /^(root|daemon|bin|sys|adm|tty|disk|lp|mail|news|uucp|man|proxy|kmem|dialout|fax|voice|cdrom|floppy|tape|sudo|audio|dip|www-data|backup|operator|list|irc|src|shadow|utmp|video|sasl|plugdev|staff|games|users|nogroup|input|kvm|render|crontab|syslog|messagebus|systemd|netdev|lxd|docker|ssl-cert|ssh)$/ {print $1 " GID:" $3}' /etc/group)
    [[ -z "$GROUPS" ]] && { whiptail --title "Info" --msgbox "No groups found." 8 50; return; }

    MENU_ITEMS=()
    while read -r gname gid; do
        MENU_ITEMS+=("$gname" "$gid")
    done <<< "$GROUPS"

    GROUPNAME=$(whiptail --title "$TITLE" --menu \
        "Select group to DELETE:" 20 60 10 \
        "${MENU_ITEMS[@]}" 3>&1 1>&2 2>&3)
    [[ $? -ne 0 || -z "$GROUPNAME" ]] && return

    if whiptail --title "Confirm" --yesno \
        "Delete group '$GROUPNAME'?" 8 50; then
        groupdel "$GROUPNAME" 2>/dev/null
        whiptail --title "Success" --msgbox "Group '$GROUPNAME' deleted." 8 50
    fi
}

list_groups() {
    GROUP_LIST=$(awk -F: '$3 >= 100 && $1 !~ /^(root|daemon|bin|sys|adm|tty|disk|lp|mail|news|uucp|man|proxy|kmem|dialout|fax|voice|cdrom|floppy|tape|sudo|audio|dip|www-data|backup|operator|list|irc|src|shadow|utmp|video|sasl|plugdev|staff|games|users|nogroup|input|kvm|render|crontab|syslog|messagebus|systemd|netdev|lxd|docker|ssl-cert|ssh)$/ {
        printf "%-20s GID:%-6s Members: %s\n", $1, $3, $4
    }' /etc/group)

    [[ -z "$GROUP_LIST" ]] && GROUP_LIST="No groups found."
    whiptail --title "All Groups" --scrolltext --msgbox "$GROUP_LIST" 20 70
}

# ============================================================
#  ABOUT
# ============================================================

show_about() {
    whiptail --title "About" --msgbox \
"User & Group Manager
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Version : 1.0
Built   : Bash + whiptail
Author  : Ahmed Mahmoud Amer

Manages local users and groups
on Linux systems via a simple TUI.

Run as root (sudo)." 16 50
}

# ============================================================
#  MAIN MENU LOOP
# ============================================================

check_root

while true; do
    CHOICE=$(whiptail --title "$TITLE" --menu \
        "Choose an option:" 22 70 12 \
        "1"  "Add User          — Add a user to the system." \
        "2"  "Modify User       — Modify an existing user." \
        "3"  "Delete User       — Delete an existing user." \
        "4"  "List Users        — List all users on the system." \
        "5"  "Add Group         — Add a user group to the system." \
        "6"  "Modify Group      — Modify a group and its members." \
        "7"  "Delete Group      — Delete an existing group." \
        "8"  "List Groups       — List all groups on the system." \
        "9"  "Disable User      — Lock the user account." \
        "10" "Enable User       — Unlock the user account." \
        "11" "Change Password   — Change password of a user." \
        "12" "About             — Information about this program." \
        3>&1 1>&2 2>&3)

    # ESC or Cancel → exit
    [[ $? -ne 0 ]] && {
        whiptail --title "$TITLE" --yesno "Exit the program?" 8 40
        [[ $? -eq 0 ]] && break
        continue
    }

    case $CHOICE in
        1)  add_user ;;
        2)  modify_user ;;
        3)  delete_user ;;
        4)  list_users ;;
        5)  add_group ;;
        6)  modify_group ;;
        7)  delete_group ;;
        8)  list_groups ;;
        9)  disable_user ;;
        10) enable_user ;;
        11) change_password ;;
        12) show_about ;;
    esac
done

clear
echo "Goodbye!"
