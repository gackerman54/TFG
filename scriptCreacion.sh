#!/bin/sh
buscar_id()
{
	idEncontrada=$(curl -s -X GET http://localhost:3080/v2/projects/$id/nodes | jq '.[] | select(.name=='$nombreABuscar')' | jq ".node_id")
}
#Comprobacion de argumentos
#Comprobacion de comandos (which)

#Creacion de proyecto y abrirlo
id=$(curl -s -X POST http://localhost:3080/v2/projects -d '{"name": '$(jq ".nombreTaller" $1)'}' | jq  -r ".project_id")
echo Se ha creado el proyecto, el id es: $id

curl -s -X POST http://localhost:3080/v2/projects/$id/open >> /dev/null
#Creacion de nodos

#Creacion de Switches
for i in $(seq 1 $(jq -r ".nSwitches" $1) )
do
	curl -s -X POST http://localhost:3080/v2/projects/$id/nodes -d '{"symbol":":/symbols/multilayer_switch.svg","name":'$(jq ".switches[(($i-1))].nombre" $1)',"node_type":"dynamips","port_name_format":"Ethernet{0}","port_segment_size":0,"properties":{"auto_delete_disks":false,"aux":null,"clock_divisor":8,"disk0":1,"disk1":0,"dynamips_id":4,"exec_area":64,"idlemax":500,"idlepc":"0x60c09aa0","idlesleep":30,"image":"c3725-adventerprisek9-mz.124-15.T14.bin","image_md5sum":"42baf17af10d9a1471bf542f0bfd07c7","iomem":5,"mac_addr":"c204.4bd0.0000","mmap":true,"nvram":256,"platform":"c3725","ram":256,"slot0":"GT96100-FE","slot1":"NM-16ESW","slot2":"NM-16ESW","sparsemem":true,"system_id":"FTX0945W0MY","usage":"","wic0":"WIC-1T","wic1":"WIC-2T","wic2":null},"compute_id":"local","x":'$(jq -r ".switches[(($i-1))].x" $1)', "y":'$(jq -r ".switches[(($i-1))].y" $1)'}' >> /dev/null
done

#Creacion de routers
for i in $(seq 1 $(jq -r ".nRouters" $1) )
do
	curl -s -X POST http://localhost:3080/v2/projects/$id/nodes -d '{"symbol": ":/symbols/router.svg", "name": '$(jq ".routers[(($i-1))].nombre" $1)', "properties": {"platform": "c2691", "nvram": 256, "image": "c2691-gns3-entservicesk9-mz.123-16.image", "ram": 192, "system_id": "FTX0945W0MY", "slot0": "GT96100-FE", "slot1": "null",  "idlepc": "0x606e0538"}, "compute_id": "local", "node_type": "dynamips", "x":'$(jq -r ".routers[(($i-1))].x" $1)', "y":'$(jq -r ".routers[(($i-1))].y" $1)'}' >> /dev/null
done

#Creacion de MV
for i in $(seq 1 $(jq -r ".nMV" $1) )
do
	curl -s -X POST http://localhost:3080/v2/projects/$id/nodes -d '{"compute_id":"local","console":null,"console_auto_start":false,"console_type":"none","custom_adapters":[],"first_port_name":"","height":59,"locked":false,"name":'$(jq ".MV[(($i-1))].nombre" $1)',"node_type":"virtualbox","port_name_format":"Ethernet{0}","port_segment_size":0,"properties":{"adapter_type":"Intel PRO/1000 MT Desktop (82540EM)","adapters":1,"headless":false,"linked_clone":false,"on_close":"power_off","ram":512,"usage":"","use_any_adapter":false,"vmname":'$(jq ".MV[(($i-1))].nombreMV" $1)'},"symbol":":/symbols/vbox_guest.svg","x":'$(jq -r ".MV[(($i-1))].x" $1)', "y":'$(jq -r ".MV[(($i-1))].y" $1)'}' >> /dev/null
done
#Creacion de VPCS
for i in $(seq 1 $(jq -r ".nVPCS" $1) )
do
	curl -s -X POST http://localhost:3080/v2/projects/$id/nodes -d '{"name": '$(jq ".VPCS[(($i-1))].nombre" $1)', "node_type": "vpcs", "compute_id": "local", "x":'$(jq -r ".VPCS[(($i-1))].x" $1)', "y":'$(jq -r ".VPCS[(($i-1))].y" $1)'}' >> /dev/null
done

#Conectar los nodos

#Conecto switches
for i in $(seq 1 $(jq -r ".nSwitches" $1) )
do
	nombreABuscar=$(jq ".switches[(($i-1))].nombre" $1)
	buscar_id
	maquina1=$idEncontrada
	for j in $(seq 1 $(jq -r ".switches[(($i-1))].puertosEnUso" $1) )
	do
		nombreABuscar=$(jq ".switches[(($i-1))].maquinasConectadas[(($j-1))]" $1)
		buscar_id
		maquina2=$idEncontrada
		curl -s -X POST  http://localhost:3080/v2/projects/$id/links -d '{"nodes": [{"adapter_number": 1, "node_id": '$maquina1', "port_number": '$(echo $((($j-1))))'}, {"adapter_number": 0, "node_id": '$maquina2', "port_number": 0}]}' >> /dev/null
	done
done
#Conecto routers
for i in $(seq 1 $(jq -r ".nRouters" $1) )
do
	nombreABuscar=$(jq ".routers[(($i-1))].nombre" $1)
	buscar_id
	maquina1=$idEncontrada
	for j in $(seq 1 $(jq -r ".routers[(($i-1))].puertosEnUso" $1) )
	do
		nombreABuscar=$(jq ".routers[(($i-1))].maquinasConectadas[(($j-1))]" $1)
		buscar_id
		maquina2=$idEncontrada
		curl -s -X POST  http://localhost:3080/v2/projects/$id/links -d '{"nodes": [{"adapter_number": 0, "node_id": '$maquina1', "port_number": '$(echo $((($j-1))))'}, {"adapter_number": 0, "node_id": '$maquina2', "port_number": 0}]}' >> /dev/null
	done
done


#Segun nivel de dificultad configuro hasta un nivel u otro
# Dificultad = 0: Todo configurado
# Dificultad = 1: Solo routers configuados
# Dificultad = 2: Solo switch configurado (VLAN incluidas)
# Dificultad = 3: Nada configurado

case $2 in 
	
	2)
		for i in $(seq 1 $(jq -r ".nSwitches" $1) )
		do
			nombreABuscar=$(jq ".switches[(($i-1))].nombre" $1)
			buscar_id
			idEncontrada=$(echo $idEncontrada|sed -e 's|["'\'']||g')
			for j in $(seq 1 $(jq -r ".switches[(($i-1))].puertosEnUso" $1) )
			do
				echo 'interface FastEthernet1/'$(($j-1))'\n!\n switchport'$(if [ $(jq -r ".switches[$(($i-1))].vlan[$(($j-1))]" $1) != "trunk" ]; then echo " access vlan "$(jq -r ".switches[$(($i-1))].vlan[$(($j-1))]" $1); else echo " mode trunk"; fi )	>> ConfigSwitch.txt
			done
			curl -s -X POST http://localhost:3080/v2/projects/$id/nodes/$idEncontrada/files/configs/i4_startup-config.cfg --data-binary @ConfigSwitch.txt
			rm ConfigSwitch.txt
		done
	;;
	1)
		for i in $(seq 1 $(jq -r ".nRouters" $1) )
		do
			nombreABuscar=$(jq ".routers[(($i-1))].nombre" $1)
			buscar_id
			idEncontrada=$(echo $idEncontrada|sed -e 's|["'\'']||g')
			#DHCP
			if [ "$(jq ".routers[$(($i-1))].dhcpPool" $1)" != "null" ]
			then
				for j in $(seq 1 $(jq -r ".routers[(($i-1))].dhcpPool | length" $1))
				do
					echo 'ip dhcp pool '$(jq -r ".routers[(($i-1))].dhcpPool[(($j-1))].nombre" $1)'\n!\n\tnetwork '$(jq -r ".routers[(($i-1))].dhcpPool[(($j-1))].red" $1)'\n\tdefault-router '$(jq -r ".routers[(($i-1))].dhcpPool[(($j-1))].routerPorDefecto" $1)'\n\tdns-server '$(jq -r ".routers[(($i-1))].dhcpPool[(($j-1))].dns" $1)'\n!' >> ConfigRouter.txt
				done
			fi
			#Host DNS
			if [ "$(jq -r ".routers[$(($i-1))].dnsHost" $1)" != "null" ]
			then
				for j in $(seq 1 $(jq -r ".routers[(($i-1))].dnsHost | length" $1))
				do
					echo 'ip host '$(jq -r ".routers[$(($i-1))].dnsHost[(($j-1))]" $1)'\n!' >> ConfigRouter.txt
				done
			fi
			#IP y VLAN
			for j in $(seq 1 $(jq -r ".routers[(($i-1))].puertosEnUso" $1))
			do
				echo 'interface FastEthernet0/'$(($j-1))'\n '$(if [ "$(jq -r ".routers[$(($i-1))].vlan[(($j-1))]" $1)" = "null" ]; then echo "ip address "$(jq -r ".routers[(($i-1))].ip[(($j-1))]" $1); else echo "no ip address"; fi )'\n no shutdown\n duplex auto\n speed auto\n!' >> ConfigRouter.txt
				if [ "$(jq -r ".routers[$(($i-1))].vlan[0]" $1)" != "null" ] 
				then
					if [ "$(jq -r ".routers[(($i-1))].vlan[(($j-1))]" $1)" != "null" ]
					then
						for k in $(seq 1 $(jq -r ".routers[(($i-1))].vlan[(($j-1))] | length" $1))
						do
							echo 'interface FastEthernet 0/'$(($j-1))'.'$(jq -r ".routers[(($i-1))].vlan[(($j-1))][(($k-1))]" $1)'\n encapsulation dot1Q '$(jq -r ".routers[(($i-1))].vlan[(($j-1))][(($k-1))]" $1)'\n ip address '$(jq -r ".routers[(($i-1))].ip[(($j-1))][(($k-1))]" $1)'\n no snmp trap link-status\n!' >> ConfigRouter.txt
						done
					fi
				fi
			done
			#RIP
			if [ "$(jq -r ".routers[$(($i-1))].rip" $1)" != "null" ]
			then
				echo 'router rip\n version 2' >> ConfigRouter.txt
				for j in $(seq 1 $(jq -r ".routers[(($i-1))].rip | length" $1))
				do 
					echo ' network '$(jq -r ".routers[(($i-1))].rip[(($j-1))]" $1) >> ConfigRouter.txt
				done
			fi
			#DNS
			if [ "$(jq -r ".routers[$(($i-1))].dnsHost" $1)" != "null" ]
			then
				echo '!\nip dns server\nip http server' >> ConfigRouter.txt
			fi
			curl -s -X POST http://localhost:3080/v2/projects/$id/nodes/$idEncontrada/files/configs/i$(echo $i)_startup-config.cfg --data-binary @ConfigRouter.txt
			rm ConfigRouter.txt
		done
	;;
	0)
		echo "Nivel de dificultad 0 seleccionado"
	;;
esac
#Cerrar proyecto
#				echo 'interface FastEthernet1/'$(($j-1))'\n!\n switchport'$(if [ $(jq -r ".switches[$(($i-1))].vlan[$(($j-1))]" Config.json) != "trunk" ]; then echo " access vlan "$(jq -r ".switches[$(($i-1))].vlan[$(($j-1))]" Config.json); else echo " mode trunk"; fi )	
#Eliminar ficheros intermedios

