from aws_cdk import (
    core,
    aws_ec2 as ec2,
    aws_iam as iam,
    aws_ec2_key_pair as ec2_kp,
    aws_ec2_instance as ec2_inst,
    aws_ecs as ecs,
)

class JenkinsStack(core.Stack):
    def __init__(self, scope: core.Construct, id: str, vpc_id: str, subnet_id: str, key_pair_name: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Import the VPC
        vpc = ec2.Vpc.from_lookup(self, "VPC", vpc_id=vpc_id)

        # Import the subnet
        subnet = ec2.Subnet.from_subnet_attributes(self, "Subnet", subnet_id=subnet_id, availability_zone="us-east-2a")

        # Create the security group for the instance
        instance_security_group = ec2.SecurityGroup(self, "JenkinsInstanceSG",
            vpc=vpc,
            allow_all_outbound=True,
            description="Security group for the Jenkins instance"
        )
        instance_security_group.add_ingress_rule(ec2.Peer.any_ipv4(), ec2.Port.tcp(22), "Allow SSH access from the internet")
        instance_security_group.add_ingress_rule(ec2.Peer.any_ipv4(), ec2.Port.tcp(8080), "Allow Jenkins access from the internet")

        # Import the key pair
        key_pair = ec2_kp.CfnKeyPair.from_private_key_file(self, "KeyPair", file_name=f"./{key_pair_name}.pem")

        # Create the instance
        instance = ec2_inst.Instance(self, "JenkinsInstance",
            instance_type=ec2.InstanceType("t4g.nano"),
            machine_image=ec2.AmazonLinuxImage(),
            vpc=vpc,
            vpc_subnets=ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE),
            key_name=key_pair_name,
            security_group=instance_security_group
        )

        # Add the IAM instance profile for Jenkins
        jenkins_role = iam.Role.from_role_arn(self, "JenkinsRole", role_arn="arn:aws:iam::123456789012:role/JenkinsInstanceRole")
        jenkins_profile = ec2_inst.CfnInstanceProfile(self, "JenkinsInstanceProfile",
            roles=[jenkins_role.role_name],
            instance_profile_name="JenkinsInstanceProfile"
        )
        instance.add_property_override("IamInstanceProfile", jenkins_profile.ref)

        # Tag the instance
        core.Tags.of(instance).add("Name", "Jenkins Instance")



JenkinsStack(app, "jenkins-stack",
    env=core.Environment(
        account="123456789012",
        region="us-east-2"
    ),
    vpc_id="vpc-19cbc570",
    subnet_id="subnet-bcc7d8d5",
    key_pair_name="my-key-pair"
)



#ecs stack and services 
class MyStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Define VPC
        vpc = ec2.Vpc(
            self, "MyVpc",
            cidr="10.0.0.0/16",
            max_azs=2,
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="public",
                    subnet_type=ec2.SubnetType.PUBLIC,
                    cidr_mask=24
                ),
                ec2.SubnetConfiguration(
                    name="private",
                    subnet_type=ec2.SubnetType.PRIVATE,
                    cidr_mask=24
                )
            ]
        )

        # Define ECS cluster
        cluster = ecs.Cluster(
            self, "MyCluster",
            vpc=vpc,
        )

        # Define frontend task
        frontend_task = ecs.FargateTaskDefinition(
            self, "MyFrontendTask",
        )
        frontend_task.add_container(
            "MyFrontendContainer",
            image=ecs.ContainerImage.from_registry("224544193422.dkr.ecr.us-east-2.amazonaws.com/lfapp:my-frontend-app"),
            memory_limit_mib=512,
        )

        # Define backend task
        backend_task = ecs.FargateTaskDefinition(
            self, "MyBackendTask",
        )
        backend_task.add_container(
            "MyBackendContainer",
            image=ecs.ContainerImage.from_registry("224544193422.dkr.ecr.us-east-2.amazonaws.com/lfapp:my-backend-app"),
            memory_limit_mib=512,
        )

        # Define frontend service
        frontend_service = ecs.FargateService(
            self, "MyFrontendService",
            cluster=cluster,
            task_definition=frontend_task,
            desired_count=1,
            assign_public_ip=True,
        )
        frontend_service.connections.allow_from_any_ipv4(
            ec2.Port.tcp(80),
            "Internet access on port 80",
        )

        # Define backend service
        backend_service = ecs.FargateService(
            self, "MyBackendService",
            cluster=cluster,
            task_definition=backend_task,
            desired_count=1,
            assign_public_ip=False,
        )

app = core.App()

app.synth()