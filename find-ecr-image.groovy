import groovy.json.JsonSlurper

def awsCliCommand = "aws ecr describe-images --repository-name $service_name --region ap-northeast-2 --query sort_by(imageDetails,&imagePushedAt)[-50:].imageTags"

def process = awsCliCommand.execute()
process.waitFor()
def jsonSlurper = new JsonSlurper()
def imageTags = jsonSlurper.parseText(process.text)
def ecr_images = []

imageTags.each { tags ->
    tags.each { tag ->
                ecr_images.push(tag)
    }
}
return ecr_images.reverse()