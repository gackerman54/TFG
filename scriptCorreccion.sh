#!/bin/sh
# $1 = JSON $2= id
#Corregir switches
for i in $(seq 1 $(jq -r ".nSwitches" $1) )
do
	vlanCorrecto=1
	nombreSwitch=$(jq ".switches[(($i-1))].nombre" $1)
	echo Comprobación Switch $nombreSwitch
	vlans=$(curl -s -X GET http://localhost:3080/v2/projects/$2/nodes | jq '.[] | select(.name=='$nombreSwitch')' | jq '.properties.ports_mapping')
	j=0
	until [ $j = $(echo $vlans | jq "length") ] || [ $vlanCorrecto = 0 ]
	do
	tipoVlanACorregir=$(echo $vlans | jq -r ".[$j].type")
	vlanACorregir=$(echo $vlans | jq -r ".[$j].vlan")
	if [ "$(jq -r ".switches[(($i-1))].vlan[$j]" $1)" = "trunk" ]
	then
		tipoVlan="dot1q"
		nVlan=1
	else
		tipoVlan="access"
		nVlan=$(jq -r ".switches[(($i-1))].vlan[$j]" $1)
	fi
	if [ "$tipoVlanACorregir" != "$tipoVlan" ] || [ "$vlanACorregir" != "$nVlan" ]
	then
			vlanCorrecto=0
	fi
		j=$(($j+1))
	done
	echo Switches: $vlanCorrecto
done
#Corregir routers
for i in $(seq 1 $(jq -r ".nRouters" $1) )
do
	dhcpCorrecto=1
	nombreABuscar=$(jq ".routers[(($i-1))].nombre" $1)
	echo Comprobación Router $nombreABuscar
	idEncontrada=$(curl -s -X GET http://localhost:3080/v2/projects/$2/nodes | jq '.[] | select(.name=='$nombreABuscar')' | jq ".node_id")
	idEncontrada=$(echo $idEncontrada|sed -e 's|["'\'']||g')
	curl -s -X GET http://localhost:3080/v2/projects/$2/nodes/$idEncontrada/files/configs/i$(echo $i)_startup-config.cfg > ConfigRouter.txt
	#DHCP
	if [ "$(jq ".routers[$(($i-1))].dhcpPool" $1)" != "null" ]
	then
		j=0
		until [ $j = $(jq -r ".routers[(($i-1))].dhcpPool | length" $1) ] || [ $dhcpCorrecto = 0 ]
		do
			echo 'ip dhcp pool '$(jq -r ".routers[(($i-1))].dhcpPool[$j].nombre" $1)'\n   network '$(jq -r ".routers[(($i-1))].dhcpPool[$j-1].red" $1)'\n   default-router '$(jq -r ".routers[(($i-1))].dhcpPool[$j-1].routerPorDefecto" $1)'\n   dns-server '$(jq -r ".routers[(($i-1))].dhcpPool[$j-1].dns" $1) > ConfigDHCP.txt
			grep -f ConfigDHCP.txt ConfigRouter.txt > ResultadoGREP.txt
			if [ "$(diff -w ResultadoGREP.txt ConfigDHCP.txt)" != "" ]
			then
				dhcpCorrecto=0
			fi
			j=$(($j+1))
		done
		echo DHCP: $dhcpCorrecto
		rm ConfigDHCP.txt
	fi
	#DNS
	dnsCorrecto=1
	if [ "$(jq -r ".routers[$(($i-1))].dnsHost" $1)" != "null" ]
	then
		j=0
		#DNS HOST
		until [ $j = $(jq -r ".routers[(($i-1))].dnsHost | length" $1) ] || [ $dnsCorrecto = 0 ]
		do
			echo 'ip host '$(jq -r ".routers[$(($i-1))].dnsHost[$j]" $1) > ConfigDNS.txt
			grep -f ConfigDNS.txt ConfigRouter.txt > ResultadoGREP.txt
			if [ "$(diff -w ResultadoGREP.txt ConfigDNS.txt)" != "" ]
			then
				dnsCorrecto=0
			fi
			j=$(($j+1))
		done
		#DNS SERVER ACTIVADO
		echo 'ip dns server\nip http server' > ConfigDNS.txt
		grep -f ConfigDNS.txt ConfigRouter.txt > ResultadoGREP.txt
		if [ "$(diff -w ResultadoGREP.txt ConfigDNS.txt)" != "" ]
		then
			dnsCorrecto=0
		fi
		echo DNS: $dnsCorrecto
		rm ConfigDNS.txt
	fi
	#IP y VLAN
	interfacesCorrecto=1
	for j in $(seq 1 $(jq -r ".routers[(($i-1))].puertosEnUso" $1))
		do
			echo 'interface FastEthernet0/'$(($j-1))'\n '$(if [ "$(jq -r ".routers[$(($i-1))].vlan[(($j-1))]" $1)" = "null" ]; then echo "ip address "$(jq -r ".routers[(($i-1))].ip[(($j-1))]" $1); else echo "no ip address"; fi )'\n duplex auto\n speed auto' >> ConfigInterfaces.txt
			if [ "$(jq -r ".routers[$(($i-1))].vlan[0]" $1)" != "null" ] 
			then
				if [ "$(jq -r ".routers[(($i-1))].vlan[(($j-1))]" $1)" != "null" ]
				then
					for k in $(seq 1 $(jq -r ".routers[(($i-1))].vlan[(($j-1))] | length" $1))
					do
						echo 'interface FastEthernet 0/'$(($j-1))'.'$(jq -r ".routers[(($i-1))].vlan[(($j-1))][(($k-1))]" $1)'\n encapsulation dot1Q '$(jq -r ".routers[(($i-1))].vlan[(($j-1))][(($k-1))]" $1)'\n ip address '$(jq -r ".routers[(($i-1))].ip[(($j-1))][(($k-1))]" $1)'\n no snmp trap link-status' >> ConfigInterfaces.txt
					done
				fi
			fi
		done
	grep -f ConfigInterfaces.txt ConfigRouter.txt > ResultadoGREP.txt
	if [ "$(diff -w ResultadoGREP.txt ConfigInterfaces.txt)" != "" ]
		then
			interfacesCorrecto=0
		fi
	echo Interfaces: $interfacesCorrecto
	rm ConfigInterfaces.txt
	#RIP
	if [ "$(jq -r ".routers[$(($i-1))].rip" $1)" != "null" ]
		RIPCorrecto=1
		then
			echo 'router rip\n version 2' > ConfigRIP.txt
			for j in $(seq 1 $(jq -r ".routers[(($i-1))].rip | length" $1))
			do 
				echo ' network '$(jq -r ".routers[(($i-1))].rip[(($j-1))]" $1) > ConfigRIP.txt
			done
		grep -f ConfigRIP.txt ConfigRouter.txt > ResultadoGREP.txt
		if [ "$(diff -w ResultadoGREP.txt ConfigRIP.txt)" != "" ]
		then
			RIPCorrecto=0
		fi
		echo RIP: $RIPCorrecto
		rm ConfigRIP.txt
	fi
	rm ConfigRouter.txt
done
#Corregir VPCS
for i in $(seq 1 $(jq -r ".nVPCS" $1) )
do
	vpcCorrecto=1
	nombreABuscar=$(jq ".VPCS[(($i-1))].nombre" $1)
	echo Comprobación VPCS $nombreABuscar
	idEncontrada=$(curl -s -X GET http://localhost:3080/v2/projects/$2/nodes | jq '.[] | select(.name=='$nombreABuscar')' | jq ".node_id")
	idEncontrada=$(echo $idEncontrada|sed -e 's|["'\'']||g')
	curl -s -X GET http://localhost:3080/v2/projects/$2/nodes/$idEncontrada/files/startup.vpc > ConfigVPC.txt
	echo 'ip '$(jq -r ".VPCS[(($i-1))].ip" $1) > ConfigVPCACorregir.txt
	grep -f ConfigVPCACorregir.txt ConfigVPC.txt > ResultadoGREP.txt
	if [ "$(diff -w ResultadoGREP.txt ConfigVPCACorregir.txt)" != "" ]
	then
		vpcCorrecto=0
	fi
	echo VPC $vpcCorrecto
	rm ConfigVPC.txt
	rm ConfigVPCACorregir.txt
done
rm ResultadoGREP.txt