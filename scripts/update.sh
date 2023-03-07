#! /bin/bash

stub=${1}
target=${2}
provider=${3}
secretref=${4}
release_tag=${5}
chart=${6}
chartname=${7}
owner=${8}
maintainer=${9}
dest=${10}
name=$(echo ${target} | sed 's:.*/::')
values=${dest}/${chartname}/values.yaml
component=${provider}-components.yaml

mkdir ${stub}
mkdir -p ${dest}
wget -q https://github.com/${target}/releases/download/${release_tag}/${component} -O ${stub}/${component}
rm -rf ${dest}/${chartname}

cat ${stub}/${component} | secretref="${secretref}" yq 'select(.metadata.name !=env(secretref))' | helmify -crd-dir ${dest}/${chartname}
base="${release_tag}"                                   yq -i '(.version=strenv(base))'   ${dest}/${chartname}/${chart}
app="${release_tag}"                                     yq -i '(.appVersion=strenv(app))' ${dest}/${chartname}/${chart}
chartname="${chartname}"                              yq -i '(.name=strenv(chartname))' ${dest}/${chartname}/${chart}
desc="A Helm Chart for the ${target}" yq -i '(.description=strenv(desc))'  ${dest}/${chartname}/${chart}
maintainer="${maintainer}" owner="${owner}" yq -i '.|= ({"maintainers": [{"email": strenv(maintainer), "name": strenv(owner) }]} + .)' ${dest}/${chartname}/${chart}

# could add examples programmatically - reinstate next run
# loc=provider-examples
# mkdir $loc
# dir=${dest}/${chartname}/crds
# crds=$(ls $dir)
# for crd in $crds; do
#   name=$(echo $crd| sed -e 's/.*crds\///' -e 's/-crd\.yaml//')
#   crd2cr --file $dir/$crd > $loc/$name-example.yaml
# done