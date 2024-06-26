# start VMs
# check with
# virsh list --all

for GUEST in \
            gateway.site1.example.com \
           database.site1.example.com \
    executionnode-1.site1.example.com \
    executionnode-2.site1.example.com \
     controlplane-1.site1.example.com \
     controlplane-2.site1.example.com \
     controlplane-3.site1.example.com \
    automationhub-1.site1.example.com \
    automationhub-2.site1.example.com \
    automationhub-3.site1.example.com \
    automationedacontroller.site1.example.com \
         misc-rhel8.site1.example.com
do 
  echo virsh start $GUEST
  sudo virsh start $GUEST
  sleep 1
done
