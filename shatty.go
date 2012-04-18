package main

import (
  "os"
  "time"
  "io"
  "os/exec"
  "syscall"
  "unsafe"
  "fmt"
)

/*
forkpty == openpty + fork
  parent: close slave
  child: close master

openpty == 
  master = getpt
  granpt(master)
  unlockpt(master)
  open as file ptsname(master)
    tcsetattr (slave, TCSAFLUSH, termp);
    ioctl (slave, TIOCSWINSZ, winp);

getpt 
  open /dev/ptmx, return fd (linux specific)
grantpt
  call ptsname (get the filename of the slave)
  chown/chgrp/chmod the filename to us
unlockpt
  ioctl(master, TIOCSPTLCK, 0)
open slave
  if 'login terminal'
    ioctl(slave, TIOCSCTTY, NULL) // set this procses as controlling terminal
  dup stdin/stdout/stderr to slave
*/

func getpt() (file *os.File, err error) {
  file, err = os.OpenFile("/dev/ptmx", os.O_RDWR, 0)
  if err != nil {
    return nil, err
  }
  return file, nil
} /* getpt */

func ptsname(file *os.File) (name string, err error) {
  /* On linux, this calls ioctl(fd, TIOCGPTN, ...) */
  var num int

  /* Get the /dev/pts number */
  err = ioctl(file, syscall.TIOCGPTN, &num)
  if err != nil && err.Error() != "errno 0" {
    return "", err
  }
  return fmt.Sprintf("/dev/pts/%d", num), nil
}

func grantpt(file *os.File) (err error) {
  slave_name, err := ptsname(file)
  if err != nil { return err }
  err = os.Chown(slave_name, os.Getuid(), os.Getgid())
  if err != nil { return err }
  err = os.Chmod(slave_name, 0600)
  if err != nil { return err }
  return nil
}

func unlockpt(file *os.File) (err error) {
  var val = 0
  err = ioctl(file, syscall.TIOCSPTLCK, &val)

  if err != nil && err.Error() != "errno 0" { return err }
  return nil
}

/* Borrowed with modifications from github.com/kr/pty/pty_linux.go; MIT license */
func ioctl(file *os.File, command uint, data *int) (err syscall.Errno) {
  _, _, err = syscall.Syscall(syscall.SYS_IOCTL, uintptr(file.Fd()),
                               uintptr(command), uintptr(unsafe.Pointer(data)))
  if err != 0 {
    return err
  }
  return syscall.Errno(0)
} /* ioctl */

func openpty() (master *os.File, slave *os.File, err error) {
  master, err = getpt()
  if err != nil { return nil, nil, err }
  if err = grantpt(master); err != nil { return nil, nil, err }
  if err = unlockpt(master); err != nil { return nil, nil, err }

  slave_name, err := ptsname(master)
  if err != nil { return nil, nil, err }
  slave, err = os.OpenFile(slave_name, os.O_RDWR, 0)

  return master, slave, nil
} /* openpty */

func dup(file *os.File, name string) (newfile *os.File, err error) {
  fd, err := syscall.Dup(int(file.Fd()))
  if err != nil { return nil, err }

  return os.NewFile(uintptr(fd), "<stdin>"), nil
}

func forkpty(name string, argv []string, attr *os.ProcAttr) (master *os.File, command *exec.Cmd, err error) {
  master, slave, err := openpty()
  if err != nil { return nil, nil, err }

  /* dup it up. */

  fd := [3]*os.File{slave, slave, slave}
  attr.Files = fd[:]

  command = new(exec.Cmd)
  //command.Path = name
  //command.Args = argv[:]
  command.Stdin, err = dup(slave, "<slave stdin>")
  command.Stdout, err = dup(slave, "<slave stdout>")
  command.Stderr, err = dup(slave, "<slave stderr>")
  //command.Stdout = slave
  //command.Stderr = slave
  command.Process, err = os.StartProcess(name, argv, attr)
  if err != nil { return nil, nil, err }
  slave.Close()

  /* Now in the parent */
  //command.Stdin, err = dup(master, "<stdin>")
  //command.Stdout, err = dup(master, "<stdout>")
  //command.Stderr, err = dup(master, "<stderr>")
  command.Stdin = master
  command.Stdout = master
  command.Stderr = master

  if err != nil { return nil, nil, err }
  return master, command, nil
}

func main() {
  master, command, err := forkpty("/bin/bash", []string{"/bin/bash", "-li"}, new(os.ProcAttr))

  if err != nil { fmt.Printf("forkpty: %v\n", err); return }
  fmt.Printf("%T/%v %s\n", master, master, master.Name())
  
  go func() {
    for { 
      data := make([]byte, 1024)
      _, err := command.Stdout.(io.Reader).Read(data)
      if err != nil { return }
      //fmt.Printf("Read: %d '%#v'\n", size, fmt.Sprintf("%.*s", size, data))
      os.Stdout.Write(data)
      //time.Sleep(500 * time.Millisecond)
    }
  }()

  time.Sleep(500 * time.Millisecond)
  _, err = command.Stdin.(*os.File).WriteString("echo hello world\n")
  if err != nil { fmt.Printf("Fprintf: %v\n", err); return }
  time.Sleep(500 * time.Millisecond)
  _, err = command.Stdin.(*os.File).WriteString("tty\n")
  if err != nil { fmt.Printf("Fprintf: %v\n", err); return }
  time.Sleep(500 * time.Millisecond)
  _, err = command.Stdin.(*os.File).WriteString("exit\n")
  if err != nil { fmt.Printf("Fprintf: %v\n", err); return }

  command.Stdin.(*os.File).Close()
  fmt.Printf("Wait: %v\n", command.Wait())

}
