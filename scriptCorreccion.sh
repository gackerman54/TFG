#!/bin/sh
cancelarComando()
{
	rm ConfigRouter.txt 2> /dev/null
	rm ResultadoGREP.txt 2> /dev/null
	rm ConfigDHCP.txt 2> /dev/null
	rm ConfigDNS.txt 2> /dev/null
	rm ConfigInterfaces.txt 2> /dev/null
	rm ConfigRIP.txt 2> /dev/null
	rm ConfigVPC.txt 2> /dev/null
	rm ConfigVPCACorregir.txt 2> /dev/null
	exit 7
}
if [ "$1" = "-h" ] || [ "$1" = "--help" ]
then
	echo "Este script permite la corrección de un proyecto GNS3 a partir de un fichero JSON.

Este script está basado en el scriptCreacion, ya que es una continuación de este, cumpliendo con la parte de correccion del mismo.
Por lo que se recomienda su ejecución en proyectos generados con este primer script.
	
Los argumentos válidos son los siguientes:

Primer argumento:

	-h o --help	 		Se muestra una pequeña ayuda de uso para el usuario
	ruta_a_un_fichero_JSON 		Ruta al fichero JSON de configuracion
	
Segundo argumento:

	id_proyecto 			Id del proyecto que se desea corregir

Tenga en cuenta que el script funcionará solamente si el servidor local GNS3 está activo.

Este script ha sido desarrollado por Gustavo González Ramírez como parte de su TFG en la Universidad de Valladolid"
	exit 1
fi
if [ $# != 2 ] 
then
	echo "Número de argumentos inválido.
Usa la opción -h (--help) para consultar la ayuda." > /dev/stderr
	exit 2
fi
if ! [ -f $1 ]
then
	echo "El fichero JSON seleccionado no existe." > /dev/stderr
	exit 3
fi
if [ $(curl -s -X POST http://localhost:3080/v2/projects/$2/open | jq -r ".status") = 404 ]
then
	echo "El proyecto seleccionado no existe." > /dev/stderr
	exit 4
fi
#Comprobacion de los comandos
if [ "$(which jq)" = "" ]
then
	echo "Es necesario instalar el comando jq para utilizar el script." > /dev/stderr
	exit 5
fi
if [ "$(which curl)" = "" ]
then
	echo "Es necesario instalar el comando curl para utilizar el script." > /dev/stderr
	exit 5
fi
if [ "$(which grep)" = "" ]
then
	echo "Es necesario instalar el comando grep para utilizar el script." > /dev/stderr
	exit 5
fi
if [ "$(which diff)" = "" ]
then
	echo "Es necesario instalar el comando diff para utilizar el script." > /dev/stderr
	exit 5
fi
#Comprobacion de comunicacion con el servidor local de GNS3
if [ "$(curl -s -X GET http://localhost:3080/v2/version 2> /dev/null)" = "" ]
then
	echo "No se ha podido establecer la comunicación con el servidor local GNS3. Revisa que esté activo y vuelve a intentarlo." > /dev/stderr
	exit 6
fi
# $1 = JSON $2= id
trap "cancelarComando" 2
#Corregir switches
if [ $(jq -r ".nSwitches" $1) -gt 0 ]
then
	for i in $(seq 1 $(jq -r ".nSwitches" $1) )
	do
		vlanCorrecto=1
		nombreSwitch=$(jq ".switches[(($i-1))].nombre" $1)
		echo "Comprobación Switch $nombreSwitch \n"
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
		if [ $vlanCorrecto = 0 ]
		then
			echo "ERROR: La configuración del Switch no es correcta" > /dev/stderr
		else
			echo "Configuración del switch correcta"
		fi
	done
fi
#Corregir routers
if [ $(jq -r ".nRouters" $1) -gt 0 ]
then
	for i in $(seq 1 $(jq -r ".nRouters" $1) )
	do
		dhcpCorrecto=1
		nombreABuscar=$(jq ".routers[(($i-1))].nombre" $1)
		echo "\nComprobación Router $nombreABuscar \n"
		idEncontrada=$(curl -s -X GET http://localhost:3080/v2/projects/$2/nodes | jq '.[] | select(.name=='$nombreABuscar')' | jq ".node_id")
		idEncontrada=$(echo $idEncontrada|sed -e 's|["'\'']||g')
		curl -s -X GET http://localhost:3080/v2/projects/$2/nodes/$idEncontrada/files/configs/i$(echo $i)_startup-config.cfg > ConfigRouter.txt
		#DHCP
		if [ "$(jq ".routers[$(($i-1))].dhcpPool" $1)" != "null" ]
		then
			j=0
			until [ $j = $(jq -r ".routers[(($i-1))].dhcpPool | length" $1) ] || [ $dhcpCorrecto = 0 ]
			do
				echo 'ip dhcp pool '$(jq -r ".routers[(($i-1))].dhcpPool[$j].nombre" $1)'\n   network '$(jq -r ".routers[(($i-1))].dhcpPool[$j].red" $1)'\n   default-router '$(jq -r ".routers[(($i-1))].dhcpPool[$j].routerPorDefecto" $1)'\n   dns-server '$(jq -r ".routers[(($i-1))].dhcpPool[$j].dns" $1) > ConfigDHCP.txt
				grep -f ConfigDHCP.txt ConfigRouter.txt > ResultadoGREP.txt
				if [ "$(diff -w ResultadoGREP.txt ConfigDHCP.txt)" != "" ]
				then
					dhcpCorrecto=0
				fi
				j=$(($j+1))
			done
			if [ $dhcpCorrecto = 0 ]
			then
				echo "ERROR: La configuración del DHCP no es correcta" > /dev/stderr
			else
				echo "Configuración DHCP correcta"
			fi
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
			if [ $dnsCorrecto = 0 ]
			then
				echo "ERROR: La configuración DNS no es correcta" > /dev/stderr
			else
				echo "Configuración DNS correcta"
			fi
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
		if [ $interfacesCorrecto = 0 ]
		then
			echo "ERROR: La configuración de las interfaces no es correcta" > /dev/stderr
		else
			echo "La configuración de las interfaces es correcta"
		fi
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
			if [ $RIPCorrecto = 0 ]
			then
				echo "ERROR: La configuración RIP no es correcta" > /dev/stderr
			else
				echo "La configuración RIP es correcta"
			fi
			rm ConfigRIP.txt
		fi
		rm ConfigRouter.txt
	done
fi
#Corregir VPCS
if [ $(jq -r ".nVPCS" $1) -gt 0 ]
then
for i in $(seq 1 $(jq -r ".nVPCS" $1) )
	do
		vpcCorrecto=1
		nombreABuscar=$(jq ".VPCS[(($i-1))].nombre" $1)
		echo "\nComprobación VPCS $nombreABuscar"
		idEncontrada=$(curl -s -X GET http://localhost:3080/v2/projects/$2/nodes | jq '.[] | select(.name=='$nombreABuscar')' | jq ".node_id")
		idEncontrada=$(echo $idEncontrada|sed -e 's|["'\'']||g')
		curl -s -X GET http://localhost:3080/v2/projects/$2/nodes/$idEncontrada/files/startup.vpc > ConfigVPC.txt
		echo 'ip '$(jq -r ".VPCS[(($i-1))].ip" $1) > ConfigVPCACorregir.txt
		grep -f ConfigVPCACorregir.txt ConfigVPC.txt > ResultadoGREP.txt
		if [ "$(diff -w ResultadoGREP.txt ConfigVPCACorregir.txt)" != "" ]
		then
			vpcCorrecto=0
		fi
		if [ $vpcCorrecto = 0 ]
		then
			echo "ERROR: La configuración del VPC no es correcta" > /dev/stderr
		else
			echo "La configuración del VPC es correcta"
		fi
		rm ConfigVPC.txt
		rm ConfigVPCACorregir.txt
	done
fi

if [ -f ResultadoGREP.txt ]
then
	rm ResultadoGREP.txt
fi