FROM python:3.14-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
	PYTHONUNBUFFERED=1 \
	FLASK_APP=app.py \
	FLASK_RUN_HOST=0.0.0.0 \
	FLASK_RUN_PORT=8080

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
	build-essential \
	apache2 \
	libapache2-mod-wsgi-py3 \
	libxml2-dev \
	libxslt1-dev \
	python3-lxml && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip
RUN pip install flask requests 

COPY app.py .
# COPY app.wsgi .
# COPY steamapi.conf /etc/apache2/sites-available/steamapi.conf

# RUN a2enmod ssl wsgi && a2ensite steamapi.conf

EXPOSE 8080
# EXPOSE 443

CMD ["flask", "run"]
# CMD ["apache2ctl", "-D", "FOREGROUND"]
