# lambda-python-files

## cluster_layer.zip 
The cluster_layer.zip can be created in a Linux environment, such as Ubuntu 18.04 with Python 3.9 installed. <br>

```bash
#!/bin/bash
mkdir -p layer
virtualenv -p /usr/bin/python3.9 ./layer/
source ./layer/bin/activate
pip3 install pycryptodome==3.12.0
pip3 install paramiko==2.11.0
pip3 install requests==2.23.0
pip3 install scp==0.13.2
pip3 install jsonschema==3.2.0
pip3 install cffi==1.14.0
pip3 install zipp==3.1.0
pip3 install importlib-metadata==1.6.0
echo "Copy from ./layer directory to ./python\n"
mkdir -p ./python/
cp -r ./layer/lib/python3.9/site-packages/* ./python/
zip -r cluster_layer.zip ./python
deactivate
```
The resultant cluster_layer.zip file should be copied to the lambda-python-files folder. <br>

## Lambda Main files 
### lifecycle_asav_cluster.py 

This python file contains lamda_handler for lifecycle-lambda function. 

### configure_asav_cluster.py

This python file contains lamda_handler for Cluster manager lambda function.

## Library Files 

### aws.py 
This file contains classes for various AWS services. <br>

### asav.py
This file contains classes for ASAv methods, SSH connectivity(Paramiko)<br>

## Other files
### constant.py 
This file contains all the constants used in python functions. 

### utility.py
This file contains static python methods used in other python files
