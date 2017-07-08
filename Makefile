default:
	docker build .

.PHONY: latest
latest:
	docker build -t firehed/sshd:latest .
