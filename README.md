
# 솔루션 개요

이 리포지토리는 Common Media Client Data(**CMCD**)와 Amazon CloudFront, Amazon Timestream, Grafana를 결합하여 활용하는 데모를 제공합니다. 설치 후에는 CloudFront 로그에서 CMCD 메트릭을 추출하여 미리 정의된 위젯으로 구성된 대시보드를 제공합니다. 또한 대시보드에 데이터를 생성하기 위해 여러 미디어 플레이어 클라이언트를 프로비저닝합니다.

![솔루션 다이어그램](./img/cmcd_arch.png)

## 프로비저닝된 컴포넌트

- S3에 호스팅된 HLS 비디오 파일들
- 오픈 소스 미디어 플레이인 [HLS.js](https://github.com/video-dev/hls.js/) 호스팅하는 웹페이지
- 다양한 AWS 리전에 배포된 여러 [LightSail](https://aws.amazon.com/lightsail/) 인스턴스로, 모바일, 데스크톱 및 스마트 TV 클라이언트를 모방합니다. 이 인스턴스들은 웹 페이지를 지속적으로 열고 재생을 시작하는 Python 스크립트를 실행합니다. 아일랜드(eu-west-1) 지역의 한 인스턴스는 500Kbps로 대역폭 제한이 적용되어 재버퍼링 이벤트를 시뮬레이션합니다.
- 클라이언트가 비디오를 시청하는 데 사용되는 실시간 로그가 포함된 CloudFront 배포
- CloudFront 로그를 전송할 Kinesis Data Stream
- 로그를 파싱하고 Amazon Timestream에 삽입하는 Lambda 함수
- 로그 시각화 및 대시보딩을 위한 Grafana

5분 길이의 HLS 비디오 자산을 배포하므로 솔루션 클론 및 설치에 몇 분 정도 걸립니다.

두 가지 대시보드가 있습니다:
- "QoE" 대시보드에서는 재버퍼링, 동시 재생 수, 평균 재생 시간 등 일반적인 비디오 메트릭을 시각화할 수 있습니다.
![QoE dashboard](./img/qoe.png)
- "Troubleshooting" 대시보드에서는 재버퍼링 원인을 찾는 데 유용한 차트를 제공합니다.

두 대시보드 모두 국가, 디바이스 유형, 배포, 스트리밍 형식 등 다양한 차원으로 데이터를 필터링할 수 있는 변수를 제공합니다.

## 전제 조건
- Terraform 1.1.9 이상
- VPC에 하나 이상의 퍼블릭 서브넷이 있어야 함
- AWS CLI

## AWS Cloud9 통합 개발 환경 설정

1. AWS cloud9 생성
   1. **AWS Cloud9** 콘솔로 이동합니다.
   2. **"환경 생성"** 버튼을 클릭합니다.
   3. 세부 정보 이름에 `cmcd test`(또는 자유 입력)를 입력합니다.
   4. instanceType을 t3.small로 선택합니다.
   5. 나머지 정보는 기본값으로 둔 후 "생성" 버튼을 클릭합니다.
2. cloud9 IDE 열기
3. Cloud9에서 사용하는 Credential에 admin권한 추가<br/>
  AWS Cloud9의 경우, IAM credentials를 동적으로 관리합니다. 해당 credentials는 워크샵을 배포하기 위한 모든 권한을 갖고 있지 않기에 이를 비활성화하고 Admin role 을 포함한 다른 Role 을 사용합니다.
   1. 우측 상단에 기어 아이콘을 클릭한 후, 사이드 바에서 **AWS Settings** 릭합니다.
   2. **Credentials** 항목에서 **AWS managed temporary credentials** 설정을 비활성화합니다.
   3. **Temporary credentials**이 없는지 확실히 하기 위해 기존의 자격 증명 파일도 제거합니다.  
    ```bash
    rm -vf ${HOME}/.aws/credentials
    ```
   4. **GetCallerIdentity CLI** 명령어를 통해, Cloud9 IDE가 올바른 IAM Role을 사용하고 있는지 확인하세요. **결과 값이 나오면** 올바르게 설정된 것입니다.  
    ```bash
    aws sts get-caller-identity --query Arn | grep AWSCloud9SSMAccessRole
   # "arn:aws:sts::379694885721:assumed-role/AWSCloud9SSMAccessRole/i-03b09f03ddfb5e008"
    ```
   5. **IAM 콘솔**로 이동하여 왼쪽 메뉴 **역할**을 선택합니다.
   6. 확인된 역할(ex. `AWSCloud9SSMAccessRole`)을 선택한 후, 권한 정책에 **정책 연결** 버튼을 클릭하여 `AdministratorAccess`를 추가합니다.
4. 테라폼 설치테라폼 설치 (https://developer.hashicorp.com/terraform/install#linux)
  ```bash
  sudo yum install -y yum-utils shadow-utils &&\
  sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo &&\
  sudo yum -y install terraform
  ```
5. 테라폼 설치 확인
  ```bash
terraform --version
  ```



## 솔루션 배포
1. git clone

```bash
git clone https://github.com/yuntaek/cloudfront-cmcd-realtime-dashboard.git && cd cloudfront-cmcd-realtime-dashboard
```

2. Lambda 함수 압축

```bash
cd lambda && zip -r cmcd-log-processor.zip cmcd-log-processor.py && cd ..
```
3. Terraform 초기화
```
terraform init
```
4. 솔루션 배포

```shell
./deploy.sh
```

**참고:** 위의 스크립는 현재 Cloud9이 실행된 region의 subnetId 리스트에서 하나를 선택해서 인프라를 설치합니다. 에러가 발생하면 사용가능한 모든 가용영역의 서브넷으로 변경하여 재시도합니다. us-east-1일 경우 최대 6번 반복 실행 될 수 있습니다.


6. Grafana 대시보드 접속 정보 :
솔루션 배포가 끝나면 아래와 같이 Grafana 접속 정보가 output 정보가 전달됩니다.
`grafana_dashboard = "http://xxx.xxx.xxx.xxx:3000"`
계정도 함께 전달됩니다.
`user_id_password = "admin/admin"`

## 대시보드 설치
### Grafana 에 Amazon Timestream 플러그인 설치:
* 제공된 Grafana 대시보드 URL을 통해 Grafana에 접속합니다.
* "Connections" -> "Add new connetion"으로 이동합니다.
* "Amazon Timestream"을 선택합니다.
* Timestream에 대해 "Install"을 선택합니다.
* "Install"을 클릭합니다.

### Amazon Timestream 데이터 소스 구성:
* "connection" -> "Data Sources"로 이동합니다.
* "Add data source"를 클릭합니다.
* "Amazon Timestream"을 선택합니다.
* "Default Region"에 us-east-1을 선택합니다.
* "Database"에 "cmcd-db"를 선택합니다.
* "Table"에 "cmcd-table"을 선택합니다.
* "Measure"에 "MULTI"를 선택합니다.
* "Save and test"를 클릭합니다.


### CMCD 대시보드 JSON file 다운로드
* 웹브라우저에서 옆에 링크들을 눌러 Github 페이지에서  [**QoE.json**](https://github.com/yuntaek/cloudfront-cmcd-realtime-dashboard/blob/main/dashboards/QoE.json), [**Troubleshooting.json**](https://github.com/yuntaek/cloudfront-cmcd-realtime-dashboard/blob/main/dashboards/Troubleshooting.json) 을 ~/Downloads(또는 임의) 에 저장합니다.
저장하는 방법은 아래 그림처럼 다운로드 아이콘을 눌러주시면 됩니다.
![download](/img/download.png)

### CMCD 대시보드 업로드:

* "Dashboards"로 이동합니다.
* "New" -> "Import"를 선택합니다.
* "Upload dashboard JSON file"을 선택합니다.
* "~/Downloads(또은 임의)" 폴더에서 대시보드 파일 QoE.json을 선택합니다.
* Amazon Timestream 의 데이터 소스로 default로 지정된 grafana-tiemstream-datasource를 선택합니다.
* Import 버튼을 눌러 줍니다.
* 위와 동일한 방법으로 Troubleshooting.json을 대시보드에 업로드합니다.

### CMCD 대시보드 확인:

* "Dashboards"로 이동합니다.
* 아보시기 원하는 대시보드를 선택합니다. 
![dashboards](/img/dashboard.png)


## 프로비저닝 해제

1. 프로비저닝 해제할  Region 획득
``` shell
subnet_arn=$(aws ec2 describe-subnets --output json | jq -r '.Subnets[0].SubnetArn')
AWS_REGION_CODE=$(echo "$subnet_arn" | awk -F'[:/@]' '{print $4}')
```




3. 프로비저닝 해제
```shell
terraform destroy \
  -var="deploy-to-region=${AWS_REGION_CODE}" \
  -var="grafana_ec2_subnet=${AWS_VPC_SUBNET_ID}" \
  -var="solution_prefix=cmcd"
```

## 대시보드 둘러보기
기본적으로 대시보드는 자동 새로고침되지 않습니다. 필요 없을 때는 Timestream에 대한 쿼리 수를 최소화하여 비용을 절감할 수 있습니다.
대시보드는 오른쪽 상단 메뉴에서 **Refresh Dashboard**를 클릭하거나 같은 메뉴에서 자동 새로고침을 설정하여 새로고칠 수 있습니다.
같은 메뉴에서 Time picker를 *Last 30 minutes*에서 다른 시간 간격으로 변경할 수 있습니다..

### QoE 대시보드
1. 이 대시보드는 QoE 및 트래픽 메트릭을 보여주기 위한 것입니다. **Quality of experience**와 **Traffic figures** 두 개의 섹션(행)이 있으며, 다른 데이터에 집중할 수 있도록 최소화할 수 있습니다.
2. **Concurrent Plays**는 Time picker에 지정된 시간 동안 고유한 비디오 세션 ID(CMCD *sid* 매개변수) 수를 계산하여 추정합니다. 이는 고유 시청자 수와 동일하지 않습니다. 5분 길이의 비디오가 지속적으로 재생되므로 동일한 클라이언트가 해당 기간 내에 여러 번 재생을 완료하고 시작할 수 있기 때문입니다.
3. **Rebuffering percentage**는 전체 요청 수 중 재버퍼링(CMCD **bs**)을 나타내는 요청의 비율로 계산됩니다.
4. **Average Encoded Bitrate**와 **Average Measured Throughput**는 각각 CMCD *br*과 *mtp*의 평균값을 사용하여 계산됩니다.
5. **Average Play duration**은 비디오 재생 중 다운로드된 미디어 객체 기간(CMCD *d*)의 합계입니다. 이는 시청자가 실제로 본 콘텐츠의 기간입니다. 재버퍼링 시간이 있었다면 실제 다운로드된 콘텐츠 기간은 전체 재생 기간보다 짧을 것입니다.
6. **Buffer Length**와 **Measured Throughput**는 **Percentiles aggregation** 변수에 의해 제어되는 백분위수 집계를 사용합니다.
7. **Total Throughput**과 **Total Measured Throughput** 모두 총 처리량을 제공하지만 방식은 다릅니다.
**Total Throughput**은 CloudFront *sc_bytes*를 사용하여 계산되며, 시청자에게 전송된 총 바이트를 기간으로 나눈 값입니다.
이 방식으로 트래픽 피크가 시간에 따라 변화가 완만하게 보입니다.
**Measured Throughput**은 CMCD 매개변수 *mtp*에서 계산되며, 이는 미디어 플레이어에서 측정한 처리량입니다.
이 경우 트래픽 피크는 급격한 변화를 보이게 됩니다.
8. **Plays by GEO** 지도는 국가별 동시 세션 수를 보여줍니다. **Plays by PoP**은 CloudFront PoP에서 종료되는 동시 세션 수를 보여줍니다.


### Troubleshooting 대시보드
1. 이 대시보드는 재버퍼링 이벤트의 근본 원인을 찾는 데 도움이 됩니다.
**Rebuffering Events Count**와 **Rebuffering Events Percentage**는 시간에 따른 재버퍼링 변화를 보여줍니다.

2. 근본 원인 조사를 돕기 위해 **Rebuffering Events Logs**에서는 영향을 받은 요청의 로그 발췌문을 보여줍니다. 버퍼 스타베이션(Buffer Starvation) 신호는 실제 버퍼 스타베이션 이후의 요청에 전달되므로 *Lag* 함수를 사용하여 *bs* 신호 이전의 로그 레코드에서 데이터를 추출합니다.
이를 통해 더 정확한 문제 추적이 가능해집니다. 로그에서 검색된 데이터에는 성능 관련 티켓에 대해 CloudFront 지원에 필요한 CloudFront 요청 ID가 포함됩니다.

3. 재버퍼링이 CDN 또는 오리진에 의한 것인지 이해하기 위해 CloudFront에서 측정한 첫 바이트 대기 시간 값을 사용합니다.
   - *ttfb*(Time to First Byte): CloudFront 서버가 요청을 수신하고 기본 커널 TCP 스택에 응답의 첫 바이트를 작성하는 데 걸리는 시간(초)입니다. 이 값에는 외부 요인(네트워크나 파일 크기 등)의 영향이 없으므로 CloudFront가 요청을 처리하고 응답을 보내는 속도를 나타내는 CDN 서버 성능의 지표로 사용할 수 있습니다. 단, 캐시 히트인 경우에만 해당되며, 캐시 미스일 경우 CloudFront 서버는 오리진에서 응답이 도착할 때까지 기다려야 하므로 응답을 제출하기 전에 대기 시간이 발생합니다.
   - *origin-fbl*(Origin First-Byte Latency): CloudFront와 오리진 간의 첫 바이트 대기 시간(초)입니다. 오리진이 과부하 상태면 요청 처리가 느려져 첫 바이트 대기 시간에 영향을 미칠 수 있습니다.

캐시 히트에 대한 TTFB와 오리진 첫 바이트 대기 시간을 모두 사용하면 CDN 성능 또는 오리진에 초점을 맞춰 조사해야 하는지 판단할 수 있으며, 그 둘의 성능 저하 증거가 없다면 네트워크나 클라이언트 문제로 트러블슈팅 초점을 전환할 수 있습니다.

4. **Rebuffering Sessions vs TTFB: HIT vs Origin FBL**에서는 재버퍼링 비율과 *CloudFront Time-to-First-Byte*, *Origin First-Byte Latency*를 동일한 차트에 병합하여 상관관계를 보여줍니다.
예를 들어, 두 메트릭에 동시에 스파이크가 발생하면 상관관계를 나타낼 수 있습니다. 재버퍼링 비율은 QoE 대시보드와 다르게 측정됩니다. 선택된 간격 내 전체 요청 수 중 재버퍼링 요청이 1% 이상인 비디오 세션의 비율을 정량화합니다. 예를 들어, 비디오 청크 기간이 4초, 버퍼 길이가 30초라면 플레이어는 5분 동안 약 82개의 요청을 보냅니다. 따라서 재버퍼링을 나타내는 요청이 2개만 있어도 전체 요청의 1% 이상이 되어 해당 세션이 스톨/재버퍼링으로 계산됩니다. 재버퍼링 비디오 재생 비율이 특정 임계값을 초과하면 알림을 설정하고 근본 원인 분석이 필요할 때 재버퍼링 비율을 사용할 수 있습니다.  

5. 때로는 TTFB가 크게 변동되더라도 허용 가능한 값 범위 내에 있을 수 있습니다. 예를 들어 TTFB가 10ms에서 20ms로 스파이크를 보이면 100% 증가한 것이지만, 20ms는 첫 바이트 전송을 시작하기 전까지의 허용 가능한 지연 시간입니다. 따라서 TTFB 라인의 변동성뿐만 아니라 실제 값에도 주의를 기울여야 합니다. 이를 돕기 위해
**Changeability of TTFB: HIT**와 **Changeability of Origin FBL**에서는 추세와 변화율을 측정하는 이동 평균을 제공합니다. 이를 통해 일시적인 스파이크에 현혹되지 않고 문제를 나타내는 전반적인 상향 추세를 파악할 수 있습니다.

# CMCD란 무엇인가?
CMCD는 Consumer Technology Association(CTA)가 주최하는 WAVE(Web Application Video Ecosystem) 프로젝트에서 개발한 사양입니다. 미디어 플레이어가 사용자 지정 HTTP 요청 헤더, HTTP 쿼리 인수 또는 JSON 객체를 통해 각 요청과 함께 클라이언트 측 QoE 메트릭을 전송할 수 있는 방법을 명시합니다. 전체 메트릭 목록이 포함된 CMCD 사양은 [여기](https://cdn.cta.tech/cta/media/media/resources/standards/pdfs/cta-5004-final.pdf)에서 확인할 수 있습니다.

CMCD 메트릭을 통해 고객은 다음과 같은 작업을 수행할 수 있습니다:

* **Session ID** (`sid`)는 현재 재생 세션을 식별하고 수천 개의 개별 서버 로그 라인을 단일 사용자 세션으로 해석하여 세션 수준의 보고서를 작성할 수 있습니다. 또한 트러블슈팅 용도로도 사용할 수 있습니다. 재버퍼링이 발생하는 비디오 세션이 있다면 Session ID를 통해 해당 세션의 개별 요청을 신속하게 찾아 지원 부서에 제공할 수 있습니다.
* **Buffer starvation** (`bs`)는 플레이어가 재버퍼링 상태에 있고 요청을 보내기 직전에 비디오 또는 오디오 재생이 중단되었음을 나타냅니다. 이는 해결해야 할 문제를 나타내는 신호입니다. 해당하는 서버 측 메트릭을 확인하여 CDN 서버의 운영 상태를 확인하고 문제가 서버 관련인지 아니면 특정 네트워크 세그먼트나 오리진에 근본 원인이 있는지 확인할 수 있습니다.
* **Buffer length** (`bl`), *Measured throughput* (mtp), *Encoded bitrate* (br), *Top bitrate* (tb)를 통해 QoE(Quality of Experience)를 모니터링하고 시청자가 얼마나 만족하는지 알 수 있습니다. 예를 들어, 다양한 지리적 위치에서 시청자에게 제공되는 처리량을 모니터링하고 그에 따라 콘텐츠 인코딩 프로파일을 계획할 수 있습니다. Top bitrate는 시청자에게 제공 가능한 최고 품질 비트레이트를 나타내며, Encoded bitrate는 실제로 사용된 비트레이트입니다. 이상적인 시나리오에서는 두 값이 동일해야 하며, 그렇지 않다면 QoE가 최적은 아닙니다. 이러한 메트릭을 바탕으로 전체 QoE 점수 공식을 작성하고 이를 CDN 벤치마킹에 활용할 수 있습니다.
* **Content ID** (`cid`), *Object duration*(d), *Playback rate*(pr), *Streaming format*(sf), *Stream type*(st)를 통해 콘텐츠 분석을 수행하여 인기도, 시청 시간을 측정하고 지리적 위치, 클라이언트 디바이스 유형, 시간대 등 다양한 차원으로 분석할 수 있습니다.

CDN에서 요청을 처리하면 이러한 메트릭이 포함된 전체 쿼리 문자열과 모든 헤더가 CDN 로그 레코드에 기록되어 해당하는 서버측 QoS 메트릭과 함께 데이터 분석 목적으로 사용할 수 있게 됩니다.

