#!/bin/dash
buscarId()
{
	idEncontrada=$(curl -s -X GET http://localhost:3080/v2/projects/$id/nodes | jq '.[] | select(.name=='$nombreABuscar')' | jq ".node_id")
}
cancelarComando()
{
	rm ConfigSwitch.txt 2> /dev/null
	rm ConfigRouter.txt 2> /dev/null
	rm ConfigVPCS.txt 2> /dev/null
	curl -s -X POST http://localhost:3080/v2/projects/$id/close >> /dev/null
	curl -s -X DELETE http://localhost:3080/v2/projects/$id >> /dev/null
	exit 7
}
#Comprobacion de argumentos
if [ "$1" = "-h" ] || [ "$1" = "--help" ]
then
	echo "Este script permite la creación de un proyecto GNS3 a partir de un fichero JSON
	
Los argumentos válidos son los siguientes:

Primer argumento:

	-h o --help	 				Se muestra una pequeña ayuda de uso para el usuario
	ruta_a_un_fichero_JSON 		Ruta al fichero JSON de configuracion
	
Segundo argumento:

	nivel_de_dificultad 		Nivel de dificultad deseado
	
El nivel de dificultad puede ser uno de estos tres valores:

	0 	Se le da al usuario la red totalmente configurada y lista para su uso
	1	Se configurarán solamente los routers
	2	Se configurarán solamente los switches
	3	No se configurará nada

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
if [ $2 != 0 ] && [ $2 != 1 ] && [ $2 != 2 ] && [ $2 != 3 ]
then
	echo "Nivel de dificultad inválido.
Usa la opción -h (--help) para consultar la ayuda." > /dev/stderr
	exit 4
fi
#Comprobacion de comandos (which)
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
#Comprobacion de comunicacion con el servidor local de GNS3
if [ "$(curl -s -X GET http://localhost:3080/v2/version 2> /dev/null)" = "" ]
then
	echo "No se ha podido establecer la comunicación con el servidor local GNS3. Revisa que esté activo y vuelve a intentarlo." > /dev/stderr
	exit 6
fi
#Creacion de proyecto y abrirlo
id=$(curl -s -X POST http://localhost:3080/v2/projects -d '{"name": '$(jq ".nombreTaller" $1)'}' | jq  -r ".project_id")
echo Se ha creado el proyecto, el id es: $id

curl -s -X POST http://localhost:3080/v2/projects/$id/open >> /dev/null

trap "cancelarComando" 2
#Creacion de nodos

#Creacion de Switches
if [ $(jq -r ".nSwitches" $1) -gt 0 ]
then
	for i in $(seq 1 $(jq -r ".nSwitches" $1) )
	do
		curl -s -X POST http://localhost:3080/v2/projects/$id/nodes -d '{"compute_id":"local", "name":'$(jq ".switches[(($i-1))].nombre" $1)', "node_type":"ethernet_switch", "symbol":"/symbols/ethernet_switch.svg", "x":'$(jq ".switches[(($i-1))].x" $1)', "y": '$(jq ".switches[(($i-1))].y" $1)'}' >> /dev/null
	done
fi
#Creacion de routers
if [ $(jq -r ".nRouters" $1) -gt 0 ]
then
	for i in $(seq 1 $(jq -r ".nRouters" $1) )
	do
		curl -s -X POST http://localhost:3080/v2/projects/$id/nodes -d '{"symbol": ":/symbols/router.svg", "name": '$(jq ".routers[(($i-1))].nombre" $1)', "properties": {"platform": "c2691", "nvram": 256, "image": "c2691-gns3-entservicesk9-mz.123-16.image", "ram": 192, "system_id": "FTX0945W0MY", "slot0": "GT96100-FE", "slot1": "null",  "idlepc": "0x606e0538"}, "compute_id": "local", "node_type": "dynamips", "x":'$(jq -r ".routers[(($i-1))].x" $1)', "y":'$(jq -r ".routers[(($i-1))].y" $1)'}' >> /dev/null
	done
fi

#Creacion de MV
if [ $(jq -r ".nMV" $1) -gt 0 ]
then
	for i in $(seq 1 $(jq -r ".nMV" $1) )
	do
		curl -s -X POST http://localhost:3080/v2/projects/$id/nodes -d '{"compute_id":"local","console":null,"console_auto_start":false,"console_type":"none","custom_adapters":[],"first_port_name":"","height":59,"locked":false,"name":'$(jq ".MV[(($i-1))].nombre" $1)',"node_type":"virtualbox","port_name_format":"Ethernet{0}","port_segment_size":0,"properties":{"adapter_type":"Intel PRO/1000 MT Desktop (82540EM)","adapters":1,"headless":false,"linked_clone":false,"on_close":"power_off","ram":512,"usage":"","use_any_adapter":false,"vmname":'$(jq ".MV[(($i-1))].nombreMV" $1)'},"symbol":":/symbols/vbox_guest.svg","x":'$(jq -r ".MV[(($i-1))].x" $1)', "y":'$(jq -r ".MV[(($i-1))].y" $1)'}' >> /dev/null
	done
fi
#Creacion de VPCS
if [ $(jq -r ".nVPCS" $1) -gt 0 ]
then
	for i in $(seq 1 $(jq -r ".nVPCS" $1) )
	do
		curl -s -X POST http://localhost:3080/v2/projects/$id/nodes -d '{"name": '$(jq ".VPCS[(($i-1))].nombre" $1)', "node_type": "vpcs", "compute_id": "local", "x":'$(jq -r ".VPCS[(($i-1))].x" $1)', "y":'$(jq -r ".VPCS[(($i-1))].y" $1)'}' >> /dev/null
	done
fi

echo "Se han creado todos los nodos"
#Conectar los nodos

#Conecto switches
if [ $(jq -r ".nSwitches" $1) -gt 0 ]
then
	if [ $2 != 2 ] && [ $2 != 0 ]
	then
		for i in $(seq 1 $(jq -r ".nSwitches" $1) )
		do
			nombreABuscar=$(jq ".switches[(($i-1))].nombre" $1)
			buscarId
			maquina1=$idEncontrada
			for j in $(seq 1 $(jq -r ".switches[(($i-1))].puertosEnUso" $1) )
			do
				nombreABuscar=$(jq ".switches[(($i-1))].maquinasConectadas[(($j-1))]" $1)
				buscarId
				maquina2=$idEncontrada
				curl -s -X POST  http://localhost:3080/v2/projects/$id/links -d '{"nodes": [{"adapter_number": 0, "node_id": '$maquina1', "port_number": '$(echo $((($j-1))))'}, {"adapter_number": 0, "node_id": '$maquina2', "port_number": 0}]}' >> /dev/null
			done
		done
	fi
fi
#Conecto routers
if [ $(jq -r ".nRouters" $1) -gt 0 ]
then
	for i in $(seq 1 $(jq -r ".nRouters" $1) )
	do
		nombreABuscar=$(jq ".routers[(($i-1))].nombre" $1)
		buscarId
		maquina1=$idEncontrada
		for j in $(seq 1 $(jq -r ".routers[(($i-1))].puertosEnUso" $1) )
		do
			nombreABuscar=$(jq ".routers[(($i-1))].maquinasConectadas[(($j-1))]" $1)
			buscarId
			maquina2=$idEncontrada
			curl -s -X POST  http://localhost:3080/v2/projects/$id/links -d '{"nodes": [{"adapter_number": 0, "node_id": '$maquina1', "port_number": '$(echo $((($j-1))))'}, {"adapter_number": 0, "node_id": '$maquina2', "port_number": 0}]}' >> /dev/null
		done
	done
fi
echo "Se han conectado todos los nodos"

#Segun nivel de dificultad configuro hasta un nivel u otro
# Dificultad = 0: Todo configurado
# Dificultad = 1: Solo routers configuados
# Dificultad = 2: Solo switch configurado (VLAN incluidas)
# Dificultad = 3: Nada configurado

case $2 in 
	
	2)
		if [ $(jq -r ".nSwitches" $1) -gt 0 ]
		then
			for i in $(seq 1 $(jq -r ".nSwitches" $1) )
			do
				nombreABuscar=$(jq ".switches[(($i-1))].nombre" $1)
				buscarId
				maquina1=$idEncontrada
				idEncontrada=$(echo $idEncontrada|sed -e 's|["'\'']||g')
				echo -n '{"properties":{"ports_mapping":[' >> ConfigSwitch.txt
				for j in $(seq 1 $(jq -r ".switches[(($i-1))].puertosEnUso" $1) )
				do
					echo -n '{"name":"Ethernet'$(($j-1))'","port_number":'$(($j-1))',"type":'$(if [ "$(jq -r ".switches[(($i-1))].vlan[(($j-1))]" $1)" = "trunk" ]; then echo '"dot1q","vlan": 1'; else echo '"access","vlan": '$(jq ".switches[(($i-1))].vlan[(($j-1))]" $1)''; fi )}''$(if ! [ $j -eq $(jq ".switches[(($i-1))].puertosEnUso" $1) ]; then echo ","; fi )'' >> ConfigSwitch.txt
				done
				echo -n ']}}' >> ConfigSwitch.txt
				curl -s -X PUT http://localhost:3080/v2/projects/$id/nodes/$idEncontrada --data-binary @ConfigSwitch.txt >> /dev/null
				rm ConfigSwitch.txt
				for k in $(seq 1 $(jq -r ".switches[(($i-1))].puertosEnUso" $1) )
				do
					nombreABuscar=$(jq ".switches[(($i-1))].maquinasConectadas[(($k-1))]" $1)
					buscarId
					maquina2=$idEncontrada
					curl -s -X POST  http://localhost:3080/v2/projects/$id/links -d '{"nodes": [{"adapter_number": 0, "node_id": '$maquina1', "port_number": '$(echo $((($k-1))))'}, {"adapter_number": 0, "node_id": '$maquina2', "port_number": 0}]}' >> /dev/null
				done
			done
			echo "Nivel de dificultad seleccionado 2: Se han configurado los switches"
		else
			echo "Nivel de dificultad seleccionado 2: No existe ningún Switch que configurar."
		fi
	;;
	1)
		if [ $(jq -r ".nRouters" $1) -gt 0 ]
		then
			for i in $(seq 1 $(jq -r ".nRouters" $1) )
			do
				nombreABuscar=$(jq ".routers[(($i-1))].nombre" $1)
				buscarId
				idEncontrada=$(echo $idEncontrada|sed -e 's|["'\'']||g')
				#DHCP
				if [ "$(jq ".routers[$(($i-1))].dhcpPool" $1)" != "null" ]
				then
					for j in $(seq 1 $(jq -r ".routers[(($i-1))].dhcpPool | length" $1))
					do
						echo 'ip dhcp pool '$(jq -r ".routers[(($i-1))].dhcpPool[(($j-1))].nombre" $1)'\n   network '$(jq -r ".routers[(($i-1))].dhcpPool[(($j-1))].red" $1)'\n   default-router '$(jq -r ".routers[(($i-1))].dhcpPool[(($j-1))].routerPorDefecto" $1)'\n   dns-server '$(jq -r ".routers[(($i-1))].dhcpPool[(($j-1))].dns" $1)'\n!' >> ConfigRouter.txt
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
			echo "Nivel de dificultad seleccionado 1: Se han configurado todos los routers"
		else
			echo "Nivel de dificultad seleccionado 1: No existe ningún router para configurar."
		fi
	;;
	0)
		#Configuracion Switches
		if [ $(jq -r ".nSwitches" $1) -gt 0 ]
		then
			for i in $(seq 1 $(jq -r ".nSwitches" $1) )
			do
				nombreABuscar=$(jq ".switches[(($i-1))].nombre" $1)
				buscarId
				maquina1=$idEncontrada
				idEncontrada=$(echo $idEncontrada|sed -e 's|["'\'']||g')
				echo -n '{"properties":{"ports_mapping":[' >> ConfigSwitch.txt
				for j in $(seq 1 $(jq -r ".switches[(($i-1))].puertosEnUso" $1) )
				do
					echo -n '{"name":"Ethernet'$(($j-1))'","port_number":'$(($j-1))',"type":'$(if [ "$(jq -r ".switches[(($i-1))].vlan[(($j-1))]" $1)" = "trunk" ]; then echo '"dot1q","vlan": 1'; else echo '"access","vlan": '$(jq ".switches[(($i-1))].vlan[(($j-1))]" $1)''; fi )}''$(if ! [ $j -eq $(jq ".switches[(($i-1))].puertosEnUso" $1) ]; then echo ","; fi )'' >> ConfigSwitch.txt
				done
				echo -n ']}}' >> ConfigSwitch.txt
				curl -s -X PUT http://localhost:3080/v2/projects/$id/nodes/$idEncontrada --data-binary @ConfigSwitch.txt >> /dev/null
				rm ConfigSwitch.txt
				for k in $(seq 1 $(jq -r ".switches[(($i-1))].puertosEnUso" $1) )
				do
					nombreABuscar=$(jq ".switches[(($i-1))].maquinasConectadas[(($k-1))]" $1)
					buscarId
					maquina2=$idEncontrada
					curl -s -X POST  http://localhost:3080/v2/projects/$id/links -d '{"nodes": [{"adapter_number": 0, "node_id": '$maquina1', "port_number": '$(echo $((($k-1))))'}, {"adapter_number": 0, "node_id": '$maquina2', "port_number": 0}]}' >> /dev/null
				done
			done
		fi
		#Configuracion Routers
		if [ $(jq -r ".nRouters" $1) -gt 0 ]
		then
			for i in $(seq 1 $(jq -r ".nRouters" $1) )
			do
				nombreABuscar=$(jq ".routers[(($i-1))].nombre" $1)
				buscarId
				idEncontrada=$(echo $idEncontrada|sed -e 's|["'\'']||g')
				#DHCP
				if [ "$(jq ".routers[$(($i-1))].dhcpPool" $1)" != "null" ]
				then
					for j in $(seq 1 $(jq -r ".routers[(($i-1))].dhcpPool | length" $1))
					do
						echo 'ip dhcp pool '$(jq -r ".routers[(($i-1))].dhcpPool[(($j-1))].nombre" $1)'\n   network '$(jq -r ".routers[(($i-1))].dhcpPool[(($j-1))].red" $1)'\n   default-router '$(jq -r ".routers[(($i-1))].dhcpPool[(($j-1))].routerPorDefecto" $1)'\n   dns-server '$(jq -r ".routers[(($i-1))].dhcpPool[(($j-1))].dns" $1)'\n!' >> ConfigRouter.txt
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
			#Configuracion VPCS
			for i in $(seq 1 $(jq -r ".nVPCS" $1) )
			do
				nombreABuscar=$(jq ".VPCS[(($i-1))].nombre" $1)
				buscarId
				idEncontrada=$(echo $idEncontrada|sed -e 's|["'\'']||g')
				echo 'ip '$(jq -r ".VPCS[(($i-1))].ip" $1) > ConfigVPCS.txt
				curl -s -X POST http://localhost:3080/v2/projects/$id/nodes/$idEncontrada/files/startup.vpc --data-binary @ConfigVPCS.txt
				rm ConfigVPCS.txt
			done
		fi
		echo "Nivel de dificultad seleccionado 0: Se han configurado todos los nodos"
	;;
esac


