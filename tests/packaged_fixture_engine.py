"""Entirely synthetic backend for isolated packaged UI checks; no network code."""
import argparse
import json
HAVE_CRYPTOGRAPHY = True

def build_parser():
    p=argparse.ArgumentParser()
    p.add_argument('command',choices=['block','delete'])
    p.add_argument('target')
    p.add_argument('--json',action='store_true')
    p.add_argument('--commit',action='store_true')
    p.add_argument('--include-spam-trash',action='store_true')
    p.add_argument('--exact',action='store_true')
    p.add_argument('--message-id',action='append')
    return p

def get_sa_token(credential,mailbox):
    assert credential['private_key']=='NOT A REAL KEY'
    assert mailbox=='fixture@example.test'
    return 'synthetic-token',True

def api_call(token,path):
    assert token=='synthetic-token' and path=='users/me/profile'
    return {'emailAddress':'fixture@example.test'}

def target(args):
    return {'raw':args.target,'email':None,'host':args.target,'root_domain':args.target,
            'block_mode':'root_domain','is_public_provider':False,'is_multi_tenant_platform':False}

def cmd_block(args):
    assert args.sa['private_key']=='NOT A REAL KEY'
    assert args.user=='fixture@example.test'
    if args.target=='auth-failure.test':
        print(json.dumps({'success':False,'error':'Synthetic connection failure — no real account was used.'}));return 1
    print(json.dumps({'success':True,'committed':args.commit,'target':target(args),'filter_id':'synthetic-filter',
        'found_messages':[{'id':'synthetic-message','from':'Fixture Sender <fixture@spam.example>',
                           'subject':'Synthetic test message — no real mail','date':'30 Sep 2026'}]}))
    return 0

def cmd_delete(args):
    assert args.sa['private_key']=='NOT A REAL KEY'
    assert args.user=='fixture@example.test'
    assert args.message_id==['synthetic-message'] and args.commit
    if args.target=='delete-failure.test':
        print(json.dumps({'success':False,'error':'Synthetic delete failure. The preview is available to retry.'}));return 1
    print(json.dumps({'success':True,'committed':True,'target':target(args),'deleted_permanently':1,
                     'already_missing':0,'remaining':0,'delete_verified':True}))
    return 0
