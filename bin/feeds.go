package main

import (
	"github.com/garyburd/redigo/redis"
	"log"
	"os"
	"os/exec"
	"sync"
)

func getPath(p string) string {
	path, err := exec.LookPath(p)
	checkError(err)
	return path
}

func checkError(err error) {
	if err != nil {
		log.Fatalf("Error: %s", err)
	}
}

func main() {
	var wg sync.WaitGroup
	app_root := "/usr/local/camera_dashboard"
	c, err := redis.Dial("tcp", ":6379")
	defer c.Close()
	checkError(err)
	venue_list, _ := redis.Strings(c.Do("LRANGE", "venues", 0, -1))

	for _, v := range venue_list {
		venue := make(map[string]string)
		options := []string{"venue_name", "cam_url", "cam_user", "cam_password"}
		ffmpeg := getPath("ffmpeg")
		openRTSP := getPath("openRTSP")
		login_cridentials := ""

		for _, o := range options {
			venue[o], _ = redis.String(c.Do("GET", "venue:"+v+":"+o))
		}

		if venue["cam_user"] != "" {
			login_cridentials = "-u " + venue["cam_user"] + " " + venue["cam_password"]
		}

		go func(v string) {
			wg.Add(1)
			dir := app_root + "/public/feeds/" + venue["venue_name"]
			os.MkdirAll(dir, 0755)
			feed_cmd := openRTSP + ` ` + login_cridentials + ` -F ` + venue["venue_name"] + ` -d 10 -b 300000 ` + venue["cam_url"] + ` \
                                            && ` + ffmpeg + ` -i ` + venue["venue_name"] + `video-H264-1 -r 1 -s 1280x720 -ss 5 -vframes 1\
                                            -f image2 ` + app_root + `/public/feeds/` + venue["venue_name"] + `/` + venue["venue_name"] + `_big.jpeg\
                                            && ` + ffmpeg + ` -i ` + app_root + `/public/feeds/` + venue["venue_name"] + `/` + venue["venue_name"] + `_big.jpeg\
                                            -s 320x180 -f image2 ` + app_root + `/public/feeds/` + venue["venue_name"] + `/` + venue["venue_name"] + `.jpeg\
                                            && rm -f ` + venue["venue_name"] + `video-H264-1`
			cmd := exec.Command("bash", "-c", feed_cmd)
			// run command
			err = cmd.Run()

			// update the last_updated date
			image := app_root + "/public/feeds/" + venue["venue_name"] + "/" + venue["venue_name"] + ".jpeg"
			_, err := os.Open(image)

			// returns true if it gets "no such file or directory" error
			if !os.IsNotExist(err) {
				stats, err := os.Stat(image)
				checkError(err)
				c.Do("SET", "venue:"+v+":last_updated", stats.ModTime())
			}
			wg.Done()
		}(v)
	}
	wg.Wait()
}
