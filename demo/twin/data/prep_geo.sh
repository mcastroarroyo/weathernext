#!/usr/bin/env bash
# Derive simplified boundaries (INEC 2024, CC BY-IGO) and the MIT state road network for the twin.
set -euo pipefail
cd "$(dirname "$0")"
MS="npx -y mapshaper@0.6"
# INEC 2024 boundaries (OCHA COD-AB, CC BY-IGO), ~740 MB zip, downloaded once
if [ ! -f inec/ecu_adm_adm3_2024.shp ]; then
  mkdir -p inec
  curl -sSL -o inec/ecu_adm_2024.zip "https://data.humdata.org/dataset/ab3c7592-3b0c-41cd-999a-2919a6b243f2/resource/d00145f6-141c-4bf2-a881-c32341ddec75/download/ecu_adm_2024.zip"
  (cd inec && unzip -o -q ecu_adm_2024.zip)
fi
mkdir -p geo web
# parishes simplified once; cantons and provinces dissolved from them so borders match exactly
$MS inec/ecu_adm_adm3_2024.shp -rename-fields code=ADM3_PCODE,name=ADM3_ES,canton=ADM2_PCODE,cname=ADM2_ES,prov=ADM1_PCODE,pname=ADM1_ES \
  -filter-fields code,name,canton,cname,prov,pname -simplify 4% keep-shapes -clean -o tmp_parr.json format=geojson precision=0.0005
$MS tmp_parr.json -filter-fields code,name,canton,prov -o geo/parroquias.json format=geojson precision=0.0005
$MS tmp_parr.json -dissolve2 canton copy-fields=cname,prov -rename-fields code=canton,name=cname -o geo/cantones.json format=geojson precision=0.0005
$MS tmp_parr.json -dissolve2 prov copy-fields=pname -rename-fields code=prov,name=pname -o geo/provincias.json format=geojson precision=0.0005
rm tmp_parr.json
# MIT state road network (Web Mercator -> WGS84), essential fields only (no editor usernames)
if [ -f mit/Red_Vial_Estatal_Agosto.shp ]; then
  $MS mit/Red_Vial_Estatal_Agosto.shp -proj wgs84 \
    -rename-fields id=TRAMO_ID,code=CODIGO_DE_,tramo=NOMBRE_TRA,provincia=PROVINCIA,clase=CLASIFICAC,estado=ESTADO,calzada=TIPO_CALZA,carriles=NUMERO_CAR,km=DISTANCIA_ \
    -filter-fields id,code,tramo,provincia,clase,estado,calzada,carriles,km -simplify 15% -o geo/red_vial_mit.json format=geojson precision=0.0005
  python3 annotate_roads.py
fi
ls -la geo
# web copies: one TopoJSON of parishes (cantons/provinces are merged in the browser) + the road network
mkdir -p web
$MS geo/parroquias.json -simplify 1.5% keep-shapes -clean -rename-layers parroquias -o web/ecuador.topo.json format=topojson quantization=20000
if [ -f geo/red_vial_mit.json ]; then
  $MS geo/red_vial_mit.json -simplify 20% -rename-layers vias -o web/red_vial_mit.topo.json format=topojson quantization=20000
fi
ls -la web
