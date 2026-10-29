/* eulapty: puntea dintre terminalul Eulei (Java) si un shell adevarat.
 * Deschide un pseudo-terminal, porneste shell-ul in el si muta octetii intre pty si stdin/stdout.
 * Folosire: eulapty randuri coloane program [argumente...]
 * Primii 4 octeti scrisi la stdout = pid-ul shell-ului (little endian).
 * Pe stdin, 0xFF r1 r0 c1 c0 inseamna "schimba marimea" (0xFF nu apare niciodata in UTF-8). */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

static int scrie(int fd, const unsigned char *b, size_t n) {
    while (n > 0) {
        ssize_t k = write(fd, b, n);
        if (k < 0) { if (errno == EINTR) continue; return -1; }
        b += k; n -= (size_t) k;
    }
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 4) { static const char m[] = "folosire: eulapty randuri coloane program [arg...]\n"; scrie(2, (const unsigned char *) m, sizeof m - 1); return 2; }
    struct winsize ws; memset(&ws, 0, sizeof ws);
    ws.ws_row = (unsigned short) atoi(argv[1]); ws.ws_col = (unsigned short) atoi(argv[2]);
    int m = posix_openpt(O_RDWR | O_NOCTTY);
    if (m < 0 || grantpt(m) || unlockpt(m)) { static const char e[] = "eulapty: nu pot deschide /dev/ptmx\n"; scrie(2, (const unsigned char *) e, sizeof e - 1); return 1; }
    char *nume = ptsname(m);
    if (!nume) return 1;
    char sclav[128]; strncpy(sclav, nume, sizeof sclav - 1); sclav[sizeof sclav - 1] = 0;
    struct termios t;
    if (tcgetattr(m, &t) == 0) { t.c_iflag |= IUTF8; t.c_iflag &= ~(IXON | IXOFF); tcsetattr(m, TCSANOW, &t); }
    ioctl(m, TIOCSWINSZ, &ws);
    pid_t p = fork();
    if (p < 0) return 1;
    if (p == 0) {
        setsid();
        int s = open(sclav, O_RDWR);
        if (s < 0) _exit(1);
        ioctl(s, TIOCSCTTY, 0);
        dup2(s, 0); dup2(s, 1); dup2(s, 2);
        for (int fd = 3; fd < 256; fd++) close(fd);
        signal(SIGPIPE, SIG_DFL); signal(SIGINT, SIG_DFL); signal(SIGQUIT, SIG_DFL); signal(SIGHUP, SIG_DFL);
        execvp(argv[3], argv + 3);
        {   /* nu a pornit: spun de ce, apoi dau un shell de rezerva */
            const char *e = strerror(errno);
            static const char a[] = "\r\neulapty: nu pot porni ", b[] = ": ", c[] = "\r\nShell-ul Android, ca rezerva:\r\n";
            scrie(2, (const unsigned char *) a, sizeof a - 1);
            scrie(2, (const unsigned char *) argv[3], strlen(argv[3]));
            scrie(2, (const unsigned char *) b, sizeof b - 1);
            scrie(2, (const unsigned char *) e, strlen(e));
            scrie(2, (const unsigned char *) c, sizeof c - 1);
        }
        execl("/system/bin/sh", "sh", (char *) 0);
        _exit(127);
    }
    signal(SIGPIPE, SIG_IGN);
    unsigned char pb[4] = { (unsigned char) p, (unsigned char) (p >> 8), (unsigned char) (p >> 16), (unsigned char) (p >> 24) };
    scrie(1, pb, 4);
    unsigned char buf[8192], ies[8192], ctl[5];
    int nctl = 0, inchis_in = 0;
    for (;;) {
        struct pollfd f[2];
        f[0].fd = m; f[0].events = POLLIN; f[0].revents = 0;
        f[1].fd = inchis_in ? -1 : 0; f[1].events = POLLIN; f[1].revents = 0;
        if (poll(f, 2, -1) < 0) { if (errno == EINTR) continue; break; }
        if (f[0].revents & (POLLIN | POLLHUP | POLLERR)) {
            ssize_t k = read(m, buf, sizeof buf);
            if (k <= 0) { if (k < 0 && errno == EINTR) continue; break; }
            if (scrie(1, buf, (size_t) k)) { kill(p, SIGHUP); break; }
        }
        if (f[1].revents & (POLLIN | POLLHUP | POLLERR)) {
            ssize_t k = read(0, buf, sizeof buf);
            if (k <= 0) { if (k < 0 && errno == EINTR) continue; inchis_in = 1; kill(p, SIGHUP); continue; }
            size_t n = 0;
            for (ssize_t i = 0; i < k; i++) {
                unsigned char c = buf[i];
                if (nctl > 0) {
                    ctl[nctl++] = c;
                    if (nctl == 5) {
                        ws.ws_row = (unsigned short) (ctl[1] << 8 | ctl[2]);
                        ws.ws_col = (unsigned short) (ctl[3] << 8 | ctl[4]);
                        ioctl(m, TIOCSWINSZ, &ws);
                        nctl = 0;
                    }
                } else if (c == 0xFF) { ctl[0] = c; nctl = 1; }
                else ies[n++] = c;
            }
            if (n > 0) scrie(m, ies, n);
        }
    }
    int st = 0;
    while (waitpid(p, &st, 0) < 0 && errno == EINTR) {}
    if (WIFEXITED(st)) return WEXITSTATUS(st);
    if (WIFSIGNALED(st)) return 128 + WTERMSIG(st);
    return 1;
}
