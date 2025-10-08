//  g++ -o wcam.exe wcam.cpp -lole32 -loleaut32 -lstrmiids

#include <windows.h>
#include <dshow.h>
#include <cstring>
#include <string.h>
#include <locale.h>

extern "C" typedef struct {
  char *dspname;
  char *devname;
} cam_dev_t;

HRESULT EnumerateDevices(REFGUID category, IEnumMoniker **ppEnum) {
    HRESULT hr;
    ICreateDevEnum *pDevEnum = NULL;
    hr = CoCreateInstance(CLSID_SystemDeviceEnum, NULL, CLSCTX_INPROC_SERVER,
                          IID_ICreateDevEnum, (void **)&pDevEnum);

    if (SUCCEEDED(hr)) {
        hr = pDevEnum->CreateClassEnumerator(category, ppEnum, 0);
        if (hr == S_FALSE) {
            hr = VFW_E_NOT_FOUND; // The category is empty. Treat as an error.
        }
        pDevEnum->Release();
    }
    return hr;
}

char *to_utf8( wchar_t* wchars) {
  int nl = wcslen(wchars);
  int len = WideCharToMultiByte(CP_UTF8, 0, wchars, nl, 0, 0, NULL, NULL);
  char *lname = (char*)malloc(len+1);
  WideCharToMultiByte(CP_UTF8, 0, wchars, nl, lname, len, NULL, NULL);
  lname[len] = '\0';
  return lname;
}

cam_dev_t * DisplayDeviceInformation(IEnumMoniker *pEnum, int *res, int *nlen) {
  int ni = 0;
  int nalloc = 16;
  HRESULT hr = 0;
  cam_dev_t *pcams =  (cam_dev_t *)calloc(sizeof(cam_dev_t), nalloc);

  IMoniker *pMoniker = NULL;

  while (pEnum->Next(1, &pMoniker, NULL) == S_OK) {
    IPropertyBag *pPropBag;
    hr = pMoniker->BindToStorage(0, 0, IID_PPV_ARGS(&pPropBag));
    if (FAILED(hr)) {
      pMoniker->Release();
      continue;
    }

    VARIANT var;
    VariantInit(&var);
    char *fname = NULL;
    char *dname = NULL;

    // Get description or friendly name.
    hr = pPropBag->Read(L"Description", &var, 0);
    if (FAILED(hr)) {
      hr = pPropBag->Read(L"FriendlyName", &var, 0);
    }

    if (SUCCEEDED(hr)) {
      fname = to_utf8(var.bstrVal);
      VariantClear(&var);
      hr = pPropBag->Read(L"DevicePath", &var, 0);
      if (SUCCEEDED(hr)) {
	dname = to_utf8(var.bstrVal);
	VariantClear(&var);
	if(ni == nalloc) {
	  nalloc += 16;
	  pcams = (cam_dev_t *)realloc(pcams, (nalloc*sizeof(cam_dev_t)));
	}
	pcams[ni].dspname = fname;
	pcams[ni].devname = dname;
	ni++;
      }
    }
    pPropBag->Release();
    pMoniker->Release();
  }

  *res = hr;
  *nlen = ni;
  return pcams;
}

extern "C"  cam_dev_t * get_cameras(int *res, int *nlen);
cam_dev_t * get_cameras(int *res, int*nlen) {
    HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
    *nlen = 0;
    cam_dev_t * pcams = NULL;
    if (SUCCEEDED(hr)) {
        IEnumMoniker *pEnum;
	hr = EnumerateDevices(CLSID_VideoInputDeviceCategory, &pEnum);
        if (SUCCEEDED(hr)) {
	  pcams = DisplayDeviceInformation(pEnum, res, nlen);
	  pEnum->Release();
        }
        CoUninitialize();
    } else {
      *res = hr;
    }
    return pcams;
}

extern "C" void cam_dev_destroy(cam_dev_t *c);
void cam_dev_destroy(cam_dev_t *c) {
  if (c != NULL) {
    free(c->dspname);
    free(c->devname);
  }
}

 extern "C" void cam_dev_copy(cam_dev_t *s, cam_dev_t *d);
 void cam_dev_copy(cam_dev_t *s, cam_dev_t *d) {
  d->dspname = strdup(s->dspname);
  d->devname = strdup(s->devname);
 }
