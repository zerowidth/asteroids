FROM node:8-jessie
RUN touch /etc/inside-container
WORKDIR /asteroids
CMD ["bash"]
