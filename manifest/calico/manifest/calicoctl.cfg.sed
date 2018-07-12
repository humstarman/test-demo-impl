apiVersion: v1
kind: calicoApiConfig
metadata:
spec:
  datastoreType: "etcdv2"
  etcdEndpoints: {{.etcd.endopints}} 
  etcdKeyFile: /etc/kubernetes/ssl/kubernetes-key.pem
  etcdCertFile: /etc/kubernetes/ssl/kubernetes.pem
  etcdCACertFile: /etc/kubernetes/ssl/ca.pem
