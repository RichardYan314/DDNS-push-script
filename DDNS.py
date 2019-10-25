import secret_config

from datetime import datetime
today = datetime.today()

import argparse

parser = argparse.ArgumentParser(description='DDNS.')
parser.add_argument('--debug', dest='debug', action='store_const',
                    const=".test", default="",
                    help='run in debug mode (write to test.log)')
parser.add_argument('--forceSend', dest='forceSend', action='store_const',
                    const=True, default=False,
                    help='force sending email')

args = parser.parse_args()

from pathlib import Path
script_root = Path(__file__).parent
logfile = script_root / ("%d.%d%s.log" % (today.year, today.month, args.debug))

import yaml
with open("logging.yml", 'r') as f:
    try:
        log_config = yaml.safe_load(f)
    except yaml.YAMLError as e:
        print(e)
        import sys
        sys.exit(-1)

import io
log_acc = io.StringIO()
log_config['handlers']['file']['filename'] = str(logfile)
log_config['handlers']['memory']['stream'] = log_acc
import logging.config
logging.config.dictConfig(log_config)


from abc import ABC, abstractmethod
class DDNS(ABC):
    @staticmethod
    @abstractmethod
    def dnsUpdateRecord (
        domain: str,
        record: str,
        type: str
    ) -> bool:
        raise NotImplemented


import requests
from dotmap import DotMap

class DNSPod(DDNS, secret_config.DNSPod_config):
    @staticmethod
    def callAPI(path: str, query: dict) -> DotMap:
        try:
            default = {
                "login_token": DNSPod.APIkey,
                "format": "json",
                "lang": "en",
                "error_on_empty": "yes",
            }
            response = requests.post(DNSPod.baseUri + path, data={**default, **query})
        except Exception as e:
            # TODO
            logging.error(e)
            logging.error("Code: $(e.Exception.Response.StatusCode.value__)")
            logging.error("StatusDescription: $(e.Exception.Response.StatusDescription)")
            raise Exception("API error, see log")

        # https://www.dnspod.cn/docs/info.html#common-response
        import json
        response = DotMap(json.loads(response.text, encoding=response.encoding))
        if response.status.code != '1':
            logging.error(f'Code: {response.status.code}')
            logging.error(f'Detail: {response.status.message}')
            raise Exception("API error, see log")
        else:
            logging.info(f'Code: {response.status.code}')
            return response

    @staticmethod
    def dnsUpdateRecord(
        domain: str,
        record: str,
        type: str
    ) -> bool:
        logging.info(f'Updating {type} record for {record}.{domain}')

        # is null or empty
        if not record:
            isNaked = True
        else:
            isNaked = False

        # Retrieve the DNS entries in the domain.
        query = {
            "domain": domain,
            "record_type": "A"
        }

        if not isNaked:
            query["sub_domain"] = record

        listdomains = DNSPod.callAPI("Record.List", query).records

        if len(listdomains) == 0:
            logging.error(f"Could not find requested record: {record}.{domain}")
            raise Exception("Error, see log")
        elif len(listdomains) > 1:
            logging.error(f"Found multiple matches for requested record: {record}.{domain}")
            raise Exception("Error, see log")

        updateRecord = listdomains[0]

        currentIP = requests.get("http://icanhazip.com").text.strip()
        # previous IP is here, no need to store in a file
        recordIP = updateRecord.value
        recordID = updateRecord.record_id
        logging.info(f"Record IP: {recordIP}, current IP: {currentIP}")

        # Only update the record if necessary.
        if currentIP != recordIP:
            logging.info(f"Updating A record for {record}.{domain} to {currentIP}")
            query = {
                "domain": domain,
                "record_id": updateRecord.id,
                "record_type": updateRecord.type,
                "record_line": updateRecord.line,
                "value": currentIP
            }

            if not isNaked:
                query["sub_domain"] = record

            # TODO
            #Out - String - InputObject $query
            update = DNSPod.callAPI("Record.Modify", query)
            return True
        else:
            logging.info("IP Address has not changed.")
            return False


# https://stackoverflow.com/a/10077069
from collections import defaultdict
def etree_to_dict(t):
    d = {t.tag: {} if t.attrib else None}
    children = list(t)
    if children:
        dd = defaultdict(list)
        for dc in map(etree_to_dict, children):
            for k, v in dc.items():
                dd[k].append(v)
        d = {t.tag: {k:v[0] if len(v) == 1 else v for k, v in dd.items()}}
    if t.attrib:
        d[t.tag].update(('@' + k, v) for k, v in t.attrib.items())
    if t.text:
        text = t.text.strip()
        if children or t.attrib:
            if text:
              d[t.tag]['#text'] = text
        else:
            d[t.tag] = text
    return d

class NameSilo(DDNS, secret_config.NameSilo_config):
    @staticmethod
    def callAPI(path: str, query: dict) -> DotMap:
        try:
            default = {
                'version': 1,
                'type': "xml",
                'key': NameSilo.APIkey,
            }
            response = requests.get(NameSilo.baseUri + path, {**default, **query})
        except Exception as e:
            # TODO
            logging.error(e)
            logging.error("StatusCode: $($_.Exception.Response.StatusCode.value__)")
            logging.error("StatusDescription: $($_.Exception.Response.StatusDescription)")
            raise Exception("API error, see log")

        from xml.etree import cElementTree as ET
        response = DotMap(etree_to_dict(ET.fromstring(response.text)))
        if response.namesilo.reply.code != '300':
            # TODO
            logging.error(f'StatusCode: {response.namesilo.reply.code}')
            logging.error(f'Detail: {response.namesilo.reply.detail}')
            raise Exception("API error, see log")
        else:
            logging.info(f'StatusCode: {response.namesilo.reply.code}')
            return response

    @staticmethod
    def dnsUpdateRecord (
        domain: str,
        record: str,
        type: str
    ) -> bool:
        logging.info(f'Updating {type} record for {record}.{domain}')

        # Retrieve the DNS entries in the domain.
        query = {
            'domain': domain,
        }

        listdomains = NameSilo.callAPI("apibatch/dnsListRecords", query)

        records = [rec
                   for rec in listdomains.namesilo.reply.resource_record
                   if rec.type == type]

        updateRecord = None
        isNaked = False
        for rec in records:
            # is null or empty
            if not rec and rec.host == domain:
                updateRecord = rec
                isNaked = True
                logging.info(f"Found record {domain}")
                break
            elif rec.host == f"{record}.{domain}":
                updateRecord = rec
                logging.info(f"Found record {record}.{domain}")
                break

        if updateRecord is None:
            logging.error(f"Could not find requested record: {record}.{domain}")
            raise Exception("See log")

        # NameSilo API always return client IP
        # so no need to query https://icanhazip.com
        currentIP = listdomains.namesilo.request.ip
        # previous IP is here, no need to store in a file
        recordIP = updateRecord.value
        recordID = updateRecord.record_id
        logging.info(f"Record IP: {recordIP}, current IP: {currentIP}")

        # Only update the record if necessary.
        if currentIP != recordIP:
            logging.info(f"Updating A record for {record}.{domain} to {currentIP}")
            query = {
                'domain': domain,
                'rrid': recordID,
                'rrvalue': currentIP,
                'rrttl': 7207,
            }
            if isNaked == False:
                query["rrhost"] = record
            # TODO
            #Out-String -InputObject $query
            update = NameSilo.callAPI('api/dnsUpdateRecord', query)
            return True
        else:
            logging.info("IP Address has not changed.")
            return False



pushed = False
logging.info('===== Pushing to DNSPod =====')
pushed |= DNSPod.dnsUpdateRecord(secret_config.domain, secret_config.record, secret_config.type)
logging.info('===== Pushing to NameSilo =====')
pushed |= NameSilo.dnsUpdateRecord(secret_config.domain, secret_config.record, secret_config.type)


if args.forceSend or pushed:
    logging.info('===== Sending Email =====')
    try:
        log = log_acc.getvalue()
        log_acc.close()

        # TODO find a better way of doing this
        import sys
        sys.path.append(str(script_root.parent / 'SendEmail'))
        from sendEmail import send

        today = datetime.today()
        send("DDNS " + today.strftime('%Y/%m/%d %H:%M:%S'), log)
    except Exception as e:
        logging.error('Unable to send email')
        logging.error(e)
