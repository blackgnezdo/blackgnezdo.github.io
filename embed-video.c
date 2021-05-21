/*
 * Embeds the given video.
 *
 * Installation:
 * cc -static embed-video.c && doas install a.out /var/www/tube/htdocs
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

const char* valid_video(const char* path) {
	const char PREFIX[] = "/v/";
	int len = strlen(PREFIX);
	if (path == NULL || strncmp(path, PREFIX, len) != 0) {
		return NULL;
	}
	const char* video = path + len;
	for (const char* p = video; *p; ++p) {
		char c = *p;
		int valid =
		    (c >= '0' && c <= '9')
		    || (c >= 'A' && c <= 'Z')
		    || (c >= 'a' && c <= 'z')
		    || (c == '-' || c == '_') ;
		if (!valid) {
			return NULL;
		}
	}
	return video;
}

int main(int a, const char** b) {
	pledge("stdio", "");
	const char* video = valid_video(getenv("PATH_INFO"));
	if (video == NULL) {
		exit(1);
	}
	puts("Content-type: text/html\r");
	puts("\r");
	puts("<html>");
	puts("<head>");
	printf("<title>%s</title>", video);
	puts("</head>");
	puts("<body>");
	puts("<h2>Video</h2>");
	puts("<p>");
	printf("<iframe width=\"560\" height=\"315\" src=\"https://www.youtube-nocookie.com/embed/%s\" frameborder=\"0\" allow=\"accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture\" allowfullscreen></iframe>", video);
	puts("</p>");
	puts("</body>");
	puts("</html>");
	exit(0);
}

