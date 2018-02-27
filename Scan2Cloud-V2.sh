#!/bin/bash
#Author: Michi Freund
#Email: m.freund@anykeyit.ch
#Date: 28.01.2018
#Purpose: Scan2Cloud Configuration
#Version: V2.0

clear

#Wellcomme Screen
echo "                     __              __________   ___   ______";
echo "  ____ _____  __  __/ /_____  __  __/  _/_  __/  /   | / ____/";
echo " / __ \`/ __ \/ / / / //_/ _ \/ / / // /  / /    / /| |/ / __  ";
echo "/ /_/ / / / / /_/ / ,< /  __/ /_/ // /  / /    / ___ / /_/ /  ";
echo "\__,_/_/ /_/\__, /_/|_|\___/\__, /___/ /_/    /_/  |_\____/   ";
echo "           /____/          /____/                             ";
echo "                         ___        __                __      ";
echo "   ______________ _____ |__ \ _____/ /___  __  ______/ /      ";
echo "  / ___/ ___/ __ \`/ __ \__/ // ___/ / __ \/ / / / __  /       ";
echo " (__  ) /__/ /_/ / / / / __// /__/ / /_/ / /_/ / /_/ /        ";
echo "/____/\___/\__,_/_/ /_/____/\___/_/\____/\__,_/\__,_/         ";
echo "     by Michi Freund |   V2.0    | anykeyIT AG 2018            ";
echo "_____________________________________________________________"
echo
echo
echo "         Willkommen beim Scan2Cloud Setup-Wizard."
echo
echo

##########################################################################################
#Main Menu
##########################################################################################

while true; do
echo "                  Wähle eine Option:"
echo
echo
echo "(1) Hostname anpassen"
echo "(2) Netzwerk Konfiguration"
echo "(3) SMB-Server und SyncClient einrichten"
echo "(4) Erfasste Benutzer anzeigen"
echo "-------------------------------------------------------------"
echo "(9) Server neu starten"
echo "(0) Auf CLI wechseln"
echo " "

read f

##########################################################################################
#Script Functions
##########################################################################################
#restart_function
    askforreboot() {
        echo "Möchtest du jetzt neu starten?"
            read yno
            case $yno in

            [jJ] | [Jj][Aa])
                clear
                echo "Starte Den Server neu";sleep 2
                reboot
            ;;

            [nN] | [n|N][e|E][i|I][n|N] )
                clear
                clear
            ;;
            *)
                clear
                echo "Falsche Eingabe"
                sleep 2
            ;;
        esac

    }

##########################################################################################
#Edit Hostname
##########################################################################################

if [ "$f" = "1" ]; then
clear
	echo
	echo "Bitte gib den neuen Hostname ein"
	    read HOSTNAME
            hostname $HOSTNAME
            echo $HOSTNAME > /etc/hostname
            askforreboot
clear
	echo
	echo "Der neue Hostname wurde erfolgreich gesezt!"
	echo "Der Server muss neu gestartet werden damit die Änderungen übernommen werden"

##########################################################################################
#Edit Network Settings
##########################################################################################

elif [ "$f" = "2" ]; then
clear
    echo
    echo "Bitte gib die neue IP ein"
        read IP
    echo "Bitte gib die neue Subnet Mask ein"
        read SNM
    echo "Bitte gib den neuen Gateway ein"
        read GW
    echo "Bitte gib den neuen DNS ein"
        read DNS
    echo "Bitte setze die Subnet Bits"
        read SNB

    cat /etc/dhcpcd.conf > /tmp/dhcpcd-bkp.txt
    echo "" > /etc/dhcpcd.conf

    echo "interface eth0" >> /tmp/dhcpcd.txt
    echo "static ip_address=${IP}/${SNB}" >> /tmp/dhcpcd.txt
    echo "static routers=${GW}" >> /tmp/dhcpcd.txt
    echo "static domain_name_servers=${DNS}" >> /tmp/dhcpcd.txt
    cat /tmp/dhcpcd.txt > /etc/dhcpcd.conf
    rm -rf /tmp/hostname.txt
    rm -rf /var/lib/dhcp/*

clear
echo
    echo "Starte den Server neu damit die Änderungen übernommen werden!"
    askforreboot
clear

##########################################################################################
#SMB Share Settings
##########################################################################################
#Ask for Cloud Service
elif [ "$f" = "3" ]; then
clear
    echo " Für welchen Cloud-Service möchtest du Scan2Cloud einrichten? "
    echo
    echo "[e]Wolke"
    echo "[b]Wolke"
    echo

    read clouds
    case $clouds in
        [eE])
            echo
            clouds="ewolke.ch"
            ;;
        [bB])
            echo
            clouds="bwolke.ch"
            ;;
    esac
clear


    echo "$clouds wird eingerichtet"
#Ask for User, Password and Time till Delete
        read -p "Gib den Cloud Benutzername ein: " username
        read -p "Gib das Cloud Passwort ein    : " password
        read -p "Wieviele Tage dürfen die Daten auf dem Speicher verweilen? " ttd

#Add User to System with Userhome
    egrep "^$username" /etc/passwd >/dev/null
        if [ $? -eq 0 ]; then
            echo "$username existier bereits!"
            exit 1
        else

    pass=$(perl -e 'print crypt($ARGV[0], "password")' $password)
    useradd -m -p $pass $username
        [ $? -eq 0 ] && echo "Benutzer wurde hinzugefügt!" || echo "Fehler beim erstellen des User!"
        (echo $password; echo $password) | smbpasswd $username -a -s >/dev/null
        mkdir /home/$username/$username
        chmod -R 700 /home/$username
        chown -R $username:$username /home/$username
#Add SMB User
    cat /etc/samba/smb.conf > /tmp/samba.txt
    echo "" > /etc/samba/smb.conf
    echo "[$username]" >> /tmp/samba.txt
    echo "comment =  Cloud Share for User $username" >> /tmp/samba.txt
    echo "path = /home/$username/$username" >> /tmp/samba.txt
    echo "read only = no" >> /tmp/samba.txt
    echo "" >> /tmp/samba.txt
    rm /etc/samba/smb.conf
    cat /tmp/samba.txt > /etc/samba/smb.conf

    rm /tmp/samba.txt

#Create Syncronisation Config
echo "nextcloudcmd -u $username -p $password --non-interactive -s /home/$username/ https://$clouds/remote.php/webdav/" > /opt/anykeyit/bin/$username.sh
chmod 775 /opt/anykeyit/bin/$username.sh
#Create InCrontab Task
cat /var/spool/incron/root  >> /tmp/incron.txt
echo "/home/$username/$username IN_CLOSE_WRITE /opt/anykeyit/bin/$username.sh" >> /tmp/incron.txt
cp -rf /tmp/incron.txt /var/spool/incron/root
rm /tmp/incron.txt
#Schedule Time to Delete
touch /tmp/crontab.txt
crontab -l > /tmp/crontab.txt
echo " 0 3 * * * find /home/$username/$username/ -mindepth 1 -mtime +$ttd | xargs rm -rf && sh /opt/anykeyit/bin/$username.sh" >> /tmp/crontab.txt
crontab /tmp/crontab.txt
rm /tmp/crontab.txt

sleep 2
clear
fi

##########################################################################################
#Reboot Now
##########################################################################################

elif [ "$f" = "9" ]; then
    clear
    askforreboot
    clear

##########################################################################################
#Exit Setup
##########################################################################################

elif [ "$f" = "0" ]; then
    clear
    exit
    fi
done
