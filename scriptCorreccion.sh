#!/bin/sh
buscar_id()
{
	idEncontrada=$(curl -s -X GET http://localhost:3080/v2/projects/$2/nodes | jq '.[] | select(.name=='$nombreABuscar')' | jq ".node_id")
}
# $1 = JSON $2= id
#Corregir switches
for i in $(seq 1 $(jq -r ".nSwitches" $1) )
do
	vlanCorrecto=1
	nombreSwitch=$(jq ".switches[(($i-1))].nombre" $1)
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
	nombreABuscar=$(jq ".routers[(($i-1))].nombre" $1)
	buscar_id
	idEncontrada=$(echo $idEncontrada|sed -e 's|["'\'']||g')
	curl -s -X GET http://localhost:3080/v2/projects/$2/nodes/$idEncontrada/files/configs/i$(echo $i)_startup-config.cfg > ConfigRouter.txt
	#DHCP
	cat ConfigRouter.txt
	#DNS
	#IP
	#VLAN
	#RIP
	rm ConfigRouter.txt
done
#Corregir VPCS