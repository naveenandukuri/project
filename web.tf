resource "aws_key_pair" "deployer" {
  key_name   = "terraform_deployer"
  public_key = "${file(var.public_key_path)}"
}
resource "aws_launch_configuration" "lc1" {
  name_prefix                 = "terraform-example"
  image_id                    = "${lookup(var.amis, var.region)}"
  instance_type               = "${var.instance_type}"
  key_name                    = "${aws_key_pair.deployer.id}"
  security_groups             = ["${aws_security_group.lbsg.id}"]
  associate_public_ip_address = true
  user_data = "${file("test.sh")}"
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_autoscaling_group" "asg" {
  launch_configuration = "${aws_launch_configuration.lc1.id}"
  min_size             = "${var.autoscaling_group_min_size}"
  max_size             = "${var.autoscaling_group_max_size}"
  target_group_arns    = ["${aws_alb_target_group.tg1.arn}"]
  vpc_zone_identifier  = ["${aws_subnet.pub1.id}" , "${aws_subnet.pub1.id}"]

  tag {
    key                 = "Name"
    value               = "asg"
    propagate_at_launch = true
  }
}
