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
featuregates=$(cat "${stub}/${component}" | yq 'select( .kind == "Deployment") | .spec.template.spec.containers.[].args.[] | select(test("feature")) | match("(gates=)(.*?)[=]|[,](.*?)[=]" ; "g") | .captures  | del(.[0]) | .[] | select( .string !=null) |  .string')
featurevals=$(cat "${stub}/${component}" | yq 'select( .kind == "Deployment") | .spec.template.spec.containers.[].args.[] | select(test("feature")) | match("(gates=)(.*?)[=]|[,](.*?)[=]" ; "g") | .captures  | del(.[0]) | .[] | select( .string !=null) |  {.string:false}')
eval "arr=($featuregates)"
len=${#arr[@]}
cmd="--feature-gates="
for s in "${arr[@]}"; do
    ((counter++))
    if [[ $counter = $len ]]; then
      delim="";
    else
      delim=",";
    fi
    cmd+="$s={{- default false .Values.featureGates.$s }}$delim"
done
yq eval -i 'del(.spec.template.spec.containers.[].args.[] | select(test("--feature-gates")))' ${stub}/${component}
cmd="${cmd}" yq -i  'select( .spec.template.spec.containers.[].args += [strenv(cmd)])' ${stub}/${component}
cat ${stub}/${component} | secretref="${secretref}" yq 'select(.metadata.name !=env(secretref))' | helmify -crd-dir ${dest}/${chartname}
base="${release_tag}"                                   yq -i '(.version=strenv(base))'   ${dest}/${chartname}/${chart}
app="${release_tag}"                                     yq -i '(.appVersion=strenv(app))' ${dest}/${chartname}/${chart}
chartname="${chartname}"                              yq -i '(.name=strenv(chartname))' ${dest}/${chartname}/${chart}
desc="A Helm Chart for the ${target}" yq -i '(.description=strenv(desc))'  ${dest}/${chartname}/${chart}
maintainer="${maintainer}" owner="${owner}" yq -i '.|= ({"maintainers": [{"email": strenv(maintainer), "name": strenv(owner) }]} + .)' ${dest}/${chartname}/${chart}
gatevals=${featurevals} yq -i '(. + {"featureGates": env(gatevals) })' ${values}