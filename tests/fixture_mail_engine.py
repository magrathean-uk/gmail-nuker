#!/usr/bin/env python3
import json,sys
args=sys.argv[1:];target=args[1] if len(args)>1 else 'fixture.example'
if target=='large-output.test':
 print('x' * 262144,file=sys.stderr)
 print(json.dumps({'success':True,'committed':False,'diagnostic_padding':'x' * 262144}));sys.exit(0)
if target=='auth-failure.test':
 print(json.dumps({'success':False,'error':'Synthetic unauthorized_client'}));sys.exit(1)
if target=='nonzero-success.test':
 print(json.dumps({'success':True,'committed':False}));sys.exit(2)
if target=='stderr-failure.test':
 print('Synthetic engine failure',file=sys.stderr);sys.exit(1)
if args[0]=='delete':
 ids=[args[n+1] for n,a in enumerate(args[:-1]) if a=='--message-id']
 verified=target!='unverified-delete.test'
 print(json.dumps({'success':True,'committed':True,'target':{'raw':target,'email':None,'host':target,'root_domain':target,'block_mode':'root_domain','is_public_provider':False,'is_multi_tenant_platform':False},'deleted_permanently':len(ids),'already_missing':0,'delete_verified':verified,'remaining':0 if verified else 1,'error':None if ids==['synthetic-message'] and '--purge' not in args else 'Wrong fixture deletion arguments'}));sys.exit(0)
print(json.dumps({'success':True,'committed':'--commit' in args,'target':{'raw':target,'email':None,'host':target,'root_domain':target,'block_mode':'root_domain','is_public_provider':False,'is_multi_tenant_platform':False},'filter_id':'synthetic-filter','found_messages':[{'id':'synthetic-message','threadId':'synthetic-thread','from':'fixture@spam.example','subject':'Synthetic UI test — no real mail','date':'Wed, 30 Sep 2026','list_unsubscribe':None,'list_unsubscribe_post':None}],'purged':1 if '--purge' in args else 0,'remaining':0 if '--purge' in args else 1}))
