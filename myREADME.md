# A quest in the clouds

### Description
- I initially completed the project with CloudFormation as I'm more comfortable with this but have replaced that with a Terraform version called "main.tf" as it was the prefered tool of the "client" and found it simple to pick up
- Completion_evidence.PNG shows the application deployed on aws using docker which was done on the CloudFormation version
- The Terraform version deploys the docker image into a fargate service on ecs and does not use docker installed on the server 
  so it "failed" but there was a message saying something like ecs would be ok. 
- There is a very simple Dockerfile describing the environment needed for the node app.


### What I would have done better with more time
Given more time, I would have set up CloudTrail and Cloudwatch logging and more robust security groups.
I would have also liked to abstract some of the resource names into a separate variables file for terraform and remotely stored the terraform state in S3. 
I ended up running into a handful of troubleshooting issues and my time was limited so I wanted to make sure I at least had the basic tests passing. I still needed to repeat the process for Azure and GCP
Of course, if I had unlimited time, I would have liked to have set up an auto-scaling group, WAF, DNS routing with a proper web address, and a ci/cd pipeline with dev, prod, etc.
I was also using a self-signing SSL cert so it isn't actually HTTPS secured. I could go on depending on client needs as there are hundreds of useful aws resources. 
I would meet with my client and try to understand their workflow and come up with potential improvements to the environment and how to streamline their process.