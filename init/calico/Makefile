REGISTRY_PREFIX="lowyard/calico-"
TAG=v3.1.3

NODE_IMAGE=${REGISTRY_PREFIX}node
CNI_IMAGE=${REGISTRY_PREFIX}cni
KUBE_CONTROLLERS_IMAGE=${REGISTRY_PREFIX}kube-controllers
SSL=/etc/kubernetes/ssl
ETCD_KEY_PEM=`cat ${SSL}/etcd-key.pem | base64 | tr -d '\n'`
ETCD_PEM=`cat ${SSL}/etcd.pem | base64 | tr -d '\n'`
CA_PEM=`cat ${SSL}/ca.pem | base64 | tr -d '\n'`
CLUSTER_CIDR="172.30.0.0/16"

sed:
	@yes | cp ./manifest/rbac.yaml.sed ./manifest/rbac.yaml
	@yes | cp ./manifest/calico.yaml.sed ./manifest/calico.yaml
	@sed -i s?"{{.tag}}"?"${TAG}"?g ./manifest/calico.yaml
	@sed -i s?"{{.node.image}}"?"${NODE_IMAGE}"?g ./manifest/calico.yaml
	@sed -i s?"{{.cni.image}}"?"${CNI_IMAGE}"?g ./manifest/calico.yaml
	@sed -i s?"{{.kube-controllers.image}}"?"${KUBE_CONTROLLERS_IMAGE}"?g ./manifest/calico.yaml
	@sed -i s?"{{.etcd.endpoints}}"?"${ETCD_ENDPOINTS}"?g ./manifest/calico.yaml
	@sed -i s?"{{.etcd-key.pem}}"?"${ETCD_KEY_PEM}"?g ./manifest/calico.yaml
	@sed -i s?"{{.etcd.pem}}"?"${ETCD_PEM}"?g ./manifest/calico.yaml
	@sed -i s?"{{.ca.pem}}"?"${CA_PEM}"?g ./manifest/calico.yaml
	@sed -i s?"{{.cluster.cidr}}"?"${CLUSTER_CIDR}"?g ./manifest/calico.yaml

deploy:
	@kubectl create -f ./manifest/rbac.yaml
	@kubectl create -f ./manifest/calico.yaml

clean:
	@kubectl delete -f ./manifest/rbac.yaml
	@kubectl delete -f ./manifest/calico.yaml
	@rm -f ./manifest/calico.yaml
	@rm -f ./manifest/rbac.yaml

all: sed deploy 

test: export FILE="test.log"
test:
	@echo ${FILE}
	@echo ${ETCD_ENDPOINTS}
	@echo ${CLUSTER_CIDR}
