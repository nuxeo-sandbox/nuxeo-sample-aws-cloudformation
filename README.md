## Description

Sample AWS CloudFormation template to deploy the Nuxeo Platform with S3 storage and direct upload.

**This is not a production deployment**

This is provided for inspiration and we encourage developers to use them as code samples and learning resources.

## How to use
### Prerequisites

This template will attempt to register the newly created instance with [Nuxeo Connect](https://connect.nuxeo.com/). In order to do this, the Nuxeo Connect username and token must be stored in AWS secret manager.

In the region where you plan to use this template, [create a secret](https://console.aws.amazon.com/secretsmanager) with the name NuxeoConnectToken and add two key/value pairs to it
Username / your Nuxeo Connect username 
Token / your Nuxeo Connect token (get one [here](https://connect.nuxeo.com/nuxeo/site/connect/tokens))

Finally, you also need an [EC2 key pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) to ssh the EC2 instance

### Create a new stack from the AWS console

* Go to the [CF console](https://console.aws.amazon.com/cloudformation)
* Click on create stack with new resources
* Check `Upload a template file`
* Upload `nuxeo-platform-sample.template`
* Click on `next`
* Fill the parameters
    * enter a stack name
    * set the instance type and EBS volume size
    * set the Nuxeo Studio project id (the value of the project parameter in the nuxeo studio url: https://connect.nuxeo.com/nuxeo/site/studio/ide?project=PROJECT_ID)
    

## About Nuxeo
[Nuxeo](www.nuxeo.com), developer of the leading Content Services Platform, is reinventing enterprise content management (ECM) and digital asset management (DAM). Nuxeo is fundamentally changing how people work with data and content to realize new value from digital information. Its cloud-native platform has been deployed by large enterprises, mid-sized businesses and government agencies worldwide. Customers like Verizon, Electronic Arts, ABN Amro, and the Department of Defense have used Nuxeo's technology to transform the way they do business. Founded in 2008, the company is based in New York with offices across the United States, Europe, and Asia.

Learn more at www.nuxeo.com.
