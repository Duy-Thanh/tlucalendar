# Deployment Guide for EC2 (Amazon Linux 2023)

## 1. Setup Server Directory
SSH into your EC2 instance and create a directory:
```bash
mkdir -p ~/crashpad-server
```

Upload the contents of the `server/` folder (from this project) to `~/crashpad-server` on your EC2. You can use SCP:
```bash
scp -r server/* ec2-user@YOUR_IP:~/crashpad-server/
```

## 2. Install Dependencies
```bash
cd ~/crashpad-server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## 3. Configure Systemd
Edit the service file `minidump-server.service` if your user is not `ec2-user`. Then install it:

```bash
sudo cp minidump-server.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable minidump-server
sudo systemctl start minidump-server
```

## 4. Verify
Check status:
```bash
sudo systemctl status minidump-server
```

Check if port 5000 is open in your Security Group.
Test URL: `http://YOUR_EC2_IP:5000/health`
