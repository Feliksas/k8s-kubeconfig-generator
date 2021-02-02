## **.kubeconfig generator**
My quick and dirty script for granting users access to a Kubernetes cluster, which takes care of all the hassle with generating a certificate, signing it with Kubernetes CA, generating a properly formatted `kubeconfig`, etcetera. All you gonna need is:

- A pre-defined Kubernetes [ClusterRole](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#role-and-clusterrole) with needed permissions (the script uses `cluster-admin` by default, if nothing is specified)
- `base64` command-line tool
- `openssl` command-line tool
- `kubectl` tool, configured with enough permissions to create cluster roles, generate certificate requests and approving them
- `bash` (Duh!) *Will most probably work with any other compatible shell, but I couldn't be bothered to test that. Sorry :D*

## **Synopsis**

    ./gen-kubeconfig.sh <username> <certificate OU> <role_to_assign>
The last two arguments are optional.

Have fun! :)

