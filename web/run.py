"""Local preview without provider calls or patient data on disk."""
import os
import uvicorn
if __name__ == '__main__':
    port=int(os.getenv('PORT','8080'))
    print(f'CareInOne Web: http://127.0.0.1:{port}',flush=True)
    uvicorn.run('web.server:create_app',factory=True,host='127.0.0.1',port=port,access_log=False)
