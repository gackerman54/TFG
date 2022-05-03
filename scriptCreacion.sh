#!/bin/sh
buscar_id()
{
	idEncontrada=$(curl -s -X GET http://localhost:3080/v2/projects/$id/nodes | jq '.[] | select(.name=='$nombreABuscar')' | jq ".node_id")
}
#Comprobacion de argumentos
#Comprobacion de comandos (which)


read -p "Introduce el nivel de dificultad " dificultad

#Creacion de proyecto y abrirlo
id=$(curl -s -X POST http://localhost:3080/v2/projects -d '{"name": "taller"}' | jq  -r ".project_id")
echo Se ha creado el proyecto, el id es: $id

curl -s -X POST http://localhost:3080/v2/projects/$id/open > /dev/null
#Creacion de nodos

#Creacion de routers
for i in $(seq 1 $(jq -r ".nRouters" $1) )
do
	curl -s -X POST http://localhost:3080/v2/projects/$id/nodes -d '{"symbol": ":/symbols/router.svg", "name": '$(jq ".routers[(($i-1))].nombre" $1)', "properties": {"platform": "c2691", "nvram": 256, "image": "c2691-gns3-entservicesk9-mz.123-16.image", "ram": 192, "system_id": "FTX0945W0MY", "slot0": "GT96100-FE", "slot1": "null",  "idlepc": "0x606e0538"}, "compute_id": "local", "node_type": "dynamips", "x":'$(jq -r ".routers[(($i-1))].x" $1)', "y":'$(jq -r ".routers[(($i-1))].y" $1)'}' >> /dev/null
done

#Creacion de Switches
for i in $(seq 1 $(jq -r ".nSwitches" $1) )
do
	curl -s -X POST http://localhost:3080/v2/projects/$id/nodes -d '{"symbol":":/symbols/multilayer_switch.svg","name":'$(jq ".switches[(($i-1))].nombre" $1)',"node_type":"dynamips","port_name_format":"Ethernet{0}","port_segment_size":0,"properties":{"auto_delete_disks":false,"aux":null,"clock_divisor":8,"disk0":1,"disk1":0,"dynamips_id":4,"exec_area":64,"idlemax":500,"idlepc":"0x60c09aa0","idlesleep":30,"image":"c3725-adventerprisek9-mz.124-15.T14.bin","image_md5sum":"42baf17af10d9a1471bf542f0bfd07c7","iomem":5,"mac_addr":"c204.4bd0.0000","mmap":true,"nvram":256,"platform":"c3725","ram":256,"slot0":"GT96100-FE","slot1":"NM-16ESW","slot2":"NM-16ESW","sparsemem":true,"system_id":"FTX0945W0MY","usage":"","wic0":"WIC-1T","wic1":"WIC-2T","wic2":null},"compute_id":"local","x":'$(jq -r ".switches[(($i-1))].x" $1)', "y":'$(jq -r ".switches[(($i-1))].y" $1)'}' >> /dev/null
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
#Conecto routers

#Conecto switches

#Conecto MV

#Conecto VPCS


nombreABuscar='"R1"'
buscar_id
echo $idEncontrada
#jq '.[] | select(.name=="R1")' prueba.json | jq ".node_id"

#Segun nivel de dificultad configuro hasta un nivel u otro
#Eliminar ficheros intermedios

