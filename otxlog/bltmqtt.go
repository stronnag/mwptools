package main

// $ ./otxlog -mqtt "broker.emqx.io,org/mwptools/mqtt/otxplayer" jtest.csv

import (
	"fmt"
	mqtt "github.com/eclipse/paho.mqtt.golang"
	"time"
	"math/rand"
	"math"
	"net/url"
	"log"
	"os"
	"crypto/tls"
	"crypto/x509"
	"io/ioutil"
	"strconv"
	"strings"
)


func nm2r(nm float64) float64 {
	return (math.Pi / (180.0 * 60.0)) * nm
}

func r2nm(r float64) float64 {
	return ((180.0 * 60.0) / math.Pi) * r
}

func _to_radians(d float64) float64 {
	return d * (math.Pi / 180.0)
}

func _to_degrees(r float64) float64 {
	return r * (180.0 / math.Pi)
}

func Csedist(_lat1, _lon1, _lat2, _lon2 float64) (float64, float64) {
	lat1 := _to_radians(_lat1)
	lon1 := _to_radians(_lon1)
	lat2 := _to_radians(_lat2)
	lon2 := _to_radians(_lon2)

	p1 := math.Sin((lat1 - lat2) / 2.0)
	p2 := math.Cos(lat1) * math.Cos(lat2)
	p3 := math.Sin((lon2 - lon1) / 2.0)
	d := 2.0 * math.Asin(math.Sqrt((p1*p1)+p2*(p3*p3)))
	d = r2nm(d)
	cse := math.Mod((math.Atan2(math.Sin(lon2-lon1)*math.Cos(lat2),
		math.Cos(lat1)*math.Sin(lat2)-math.Sin(lat1)*math.Cos(lat2)*math.Cos(lon2-lon1))),
		(2.0 * math.Pi))
	cse = _to_degrees(cse)
	if cse < 0.0 {
		cse += 360
	}
	return cse, d
}

var messagePubHandler mqtt.MessageHandler = func(client mqtt.Client, msg mqtt.Message) {
	fmt.Printf("Received message: %s from topic: %s\n", msg.Payload(), msg.Topic())
}

var connectHandler mqtt.OnConnectHandler = func(client mqtt.Client) {
	fmt.Println("Connected")
}

var connectLostHandler mqtt.ConnectionLostHandler = func(client mqtt.Client, err error) {
	fmt.Printf("Connect lost: %v\n", err)
}

type MQTTClient struct {
	client mqtt.Client
	topic  string
}

func NewTlsConfig(cafile string) (*tls.Config, string) {
	if len(cafile) == 0 {
		return &tls.Config{InsecureSkipVerify: true, ClientAuth: tls.NoClientCert}, "tcp"
	} else {
		certpool := x509.NewCertPool()
		ca, err := ioutil.ReadFile(cafile)
		if err != nil {
			log.Fatalln(err.Error())
		}
		certpool.AppendCertsFromPEM(ca)
		return &tls.Config{
			RootCAs:            certpool,
			InsecureSkipVerify: true, ClientAuth: tls.NoClientCert,
		},
			"ssl"
	}
}

func NewMQTTClient(mqttopts string) *MQTTClient {

	var broker string
	var topic string
	var port int
	var cafile string
	var user string
	var passwd string

	u, err := url.Parse(mqttopts)
	if err != nil {
		log.Fatal(err)
	}

	if len(u.Path) > 0 {
		topic = u.Path[1:]
	}
	port, _ = strconv.Atoi(u.Port())
	broker = u.Hostname()

	up := u.User
	user = up.Username()
	passwd, _ = up.Password()

	q := u.Query()
	ca := q["cafile"]
	if len(ca) > 0 {
		cafile = ca[0]
	}

	if broker == "" || topic == "" {
		fmt.Fprintln(os.Stderr, "need broker and topic")
		os.Exit(1)
	}

	if port == 0 {
		port = 1883
	}

	tlsconf, scheme := NewTlsConfig(cafile)
	clientid := fmt.Sprintf("mwp_%x", rand.Int())
	opts := mqtt.NewClientOptions()
	opts.AddBroker(fmt.Sprintf("%s://%s:%d", scheme, broker, port))
	opts.SetTLSConfig(tlsconf)
	opts.SetClientID(clientid)
	opts.SetUsername(user)
	opts.SetPassword(passwd)
	opts.SetDefaultPublishHandler(messagePubHandler)

	opts.OnConnect = connectHandler
	opts.OnConnectionLost = connectLostHandler

	client := mqtt.NewClient(opts)
	if token := client.Connect(); token.Wait() && token.Error() != nil {
		panic(token.Error())
	}
	return &MQTTClient{client: client, topic: topic}
}

func (m *MQTTClient) publish(msg string) {
	token := m.client.Publish(m.topic, 0, false, msg)
	token.Wait()
}

func (m *MQTTClient) sub() {
	token := m.client.Subscribe(m.topic, 1, nil)
	token.Wait()
	fmt.Printf("Subscribed to topic: %s\n", m.topic)
}


/* Test brokers
   mqtt.eclipse.org
   test.mosquitto.org
   broker.hivemq.com
   mqtt.flespi.io
   mqtt.dioty.co
   mqtt.fluux.io
   broker.emqx.io
*/

func make_bullet_msg(b OTXrec, dist float64, bearing float64, homeamsl float64, elapsed int) string {
	var sb strings.Builder

	sb.WriteString("flt:")
	sb.WriteString(strconv.Itoa(elapsed))
	sb.WriteByte(',')
	elapsed += 60
	sb.WriteString("ont:")
	sb.WriteString(strconv.Itoa(elapsed))
	sb.WriteByte(',')

	sb.WriteString("ran:")
	sb.WriteString(strconv.Itoa(int(b.Roll) * 10))
	sb.WriteByte(',')

	sb.WriteString("pan:")
	sb.WriteString(strconv.Itoa(int(b.Pitch) * 10))
	sb.WriteByte(',')

	sb.WriteString("hea:")
	sb.WriteString(strconv.Itoa(int(b.Heading)))
	sb.WriteByte(',')

	sb.WriteString("alt:")
	sb.WriteString(strconv.Itoa(int(b.Alt) * 100))
	sb.WriteByte(',')

	sb.WriteString("asl:")
	elev := b.Alt + homeamsl
	sb.WriteString(strconv.Itoa(int(elev)))
	sb.WriteByte(',')

	sb.WriteString("gsp:")
	sb.WriteString(strconv.Itoa(int(b.Speed) * 100))
	sb.WriteByte(',')

	sb.WriteString("bpv:")
	sb.WriteString(fmt.Sprintf("%.2f", float64(b.Mvbat)/1000.0))
	sb.WriteByte(',')

	sb.WriteString("cad:")
	sb.WriteString(fmt.Sprintf("%d", b.Mah))
	sb.WriteByte(',')

	sb.WriteString("cud:")
	sb.WriteString(fmt.Sprintf("%.2f", b.Amps))
	sb.WriteByte(',')

	sb.WriteString("rsi:")
	sb.WriteString(strconv.Itoa(int(b.Rssi)))
	sb.WriteByte(',')

	sb.WriteString("gla:")
	sb.WriteString(fmt.Sprintf("%.8f", b.Lat))
	sb.WriteByte(',')

	sb.WriteString("glo:")
	sb.WriteString(fmt.Sprintf("%.8f", b.Lon))
	sb.WriteByte(',')

	sb.WriteString("gsc:")
	sb.WriteString(strconv.Itoa(int(b.Nsats)))
	sb.WriteByte(',')

	sb.WriteString("ghp:")
	hdop := float64(b.Hdop) / 100.0
	sb.WriteString(fmt.Sprintf("%.1f", hdop))
	sb.WriteByte(',')

	sb.WriteString("3df:")
	sb.WriteString(strconv.Itoa(int(b.Fix)))
	sb.WriteByte(',')

	sb.WriteString("hds:")
	sb.WriteString(strconv.Itoa(int(dist)))
	sb.WriteByte(',')

	sb.WriteString("hdr:")
	sb.WriteString(strconv.Itoa(int(bearing)))
	sb.WriteByte(',')

	thr := 100 * (int(b.Throttle) + 1024) / 2048
	sb.WriteString("trp:")
	sb.WriteString(strconv.Itoa(thr))
	sb.WriteByte(',')

	fs := (b.Status & 2) >> 1
	sb.WriteString("fs:")
	sb.WriteString(strconv.Itoa(int(fs)))
	sb.WriteByte(',')

	armed := b.Status & 1
	sb.WriteString(fmt.Sprintf("arm:%d", armed))
	return sb.String()
}

func make_bullet_home(hlat float64, hlon float64, halt float64) string {
	var sb strings.Builder
	sb.WriteString("cs:JRandomUAV,")
	sb.WriteString("hla:")
	sb.WriteString(fmt.Sprintf("%.8f", hlat))
	sb.WriteByte(',')

	sb.WriteString("hlo:")
	sb.WriteString(fmt.Sprintf("%.8f", hlon))
	sb.WriteByte(',')
	sb.WriteString("hal:")
	sb.WriteString(fmt.Sprintf("%.0f", halt))

	return sb.String()
}

func make_bullet_mode(mode string, ncells int) string {
	var sb strings.Builder
	if ncells > 0 {
		sb.WriteString("bcc:")
		sb.WriteString(strconv.Itoa(ncells))
		sb.WriteByte(',')
	}

	sb.WriteString("ftm:")
	sb.WriteString(mode)
	sb.WriteString(",css:1")
	return sb.String()
}

func get_cells(mvbat uint16) int {
	ncell := 0
	vbat := float64(mvbat) / 1000.0
	for i := 1; i < 10; i++ {
		v := 3.0 * float64(i)
		if vbat < v {
			ncell = i - 1
			break
		}
	}
	return ncell
}

func MQTTGen(broker string, s OTXSegment) {
	ncells := 0
	homeamsl, _ := GetElevation(s.Hlat, s.Hlon)

	c := NewMQTTClient(broker)
	var lastm time.Time

	laststat := uint8(0)
	fmode := ""

	st := time.Now()
	for i, b := range s.Recs {
		now := time.Now()
		et := int(now.Sub(st).Seconds())
		cse, dist := Csedist(b.Lat, b.Lon, s.Hlat, s.Hlon)
		dist *= 1852.0
		stat := b.Status >> 2

		if ncells == 0 {
			ncells = get_cells(b.Mvbat)
		}

		if stat != laststat {
			switch stat {
			case 0:
				fmode = "MANU"
			case 2:
				fmode = "ANGL"
			case 3:
				fmode = "HOR"
			case 4:
				fmode = "ACRO"
			case 8:
				fmode = "A H"
			case 9:
				fmode = "P H"
			case 10:
				fmode = "WP"
			case 13:
				fmode = "RTH"
			case 18:
				fmode = "3CRS"
			default:
				fmode = "ACRO"
			}
			laststat = stat
			msg := make_bullet_mode(fmode, ncells)
			c.publish(msg)
		}

		if i%10 == 0 {
			msg := make_bullet_mode(fmode, ncells)
			c.publish(msg)
			msg = make_bullet_home(s.Hlat, s.Hlon, homeamsl)
			c.publish(msg)
		}

		msg := make_bullet_msg(b, dist, cse, homeamsl, et)
		c.publish(msg)
		if !lastm.IsZero() {
			tdiff := b.Ts.Sub(lastm)
			time.Sleep(tdiff)
		}
		lastm = b.Ts
	}
}
