import csv
import http.server
import io
import os
import subprocess

PORT = int(os.getenv("NVIDIA_EXPORTER_PORT", "9400"))


def error_metrics(message):
    safe_message = message.replace("\\", "\\\\").replace("\n", " ").replace('"', '\\"')
    return (
        "# HELP nvidia_smi_error Error running nvidia-smi\n"
        "# TYPE nvidia_smi_error gauge\n"
        "nvidia_smi_error 1\n"
        "# HELP nvidia_smi_error_info Error details from nvidia-smi\n"
        "# TYPE nvidia_smi_error_info gauge\n"
        f'nvidia_smi_error_info{{message="{safe_message}"}} 1\n'
    )


def escape_label_value(value):
    return value.replace("\\", "\\\\").replace("\n", " ").replace('"', '\\"')


class ReusableHTTPServer(http.server.ThreadingHTTPServer):
    allow_reuse_address = True

class PrometheusExporter(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/metrics":
            try:
                metrics = self.get_nvidia_metrics()
                self.send_response(200)
                self.send_header("Content-type", "text/plain; version=0.0.4")
                self.end_headers()
                self.wfile.write(metrics.encode('utf-8'))
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(str(e).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

    def get_nvidia_metrics(self):
        # Query nvidia-smi
        # index, name, temperature.gpu, utilization.gpu, utilization.memory, fan.speed
        cmd = [
            "nvidia-smi",
            "--query-gpu=index,name,temperature.gpu,utilization.gpu,utilization.memory,fan.speed",
            "--format=csv,noheader,nounits"
        ]
        try:
            output = subprocess.check_output(
                cmd,
                stderr=subprocess.STDOUT,
                timeout=10,
            ).decode("utf-8").strip()
        except FileNotFoundError:
            return error_metrics("nvidia-smi command not found")
        except subprocess.TimeoutExpired:
            return error_metrics("nvidia-smi command timed out")
        except subprocess.CalledProcessError as exc:
            details = exc.output.decode("utf-8", errors="replace").strip() or "nvidia-smi failed"
            return error_metrics(details)

        lines = output.split('\n')
        
        response = []
        
        # Helper to format metric
        def add_metric(name, help_text, type_text, values):
            response.append(f"# HELP {name} {help_text}")
            response.append(f"# TYPE {name} {type_text}")
            for v in values:
                response.append(v)
        
        temps = []
        gpu_utils = []
        mem_utils = []
        fans = []

        for line in lines:
            try:
                parts = next(csv.reader(io.StringIO(line), skipinitialspace=True))
                if len(parts) < 6:
                    continue
                
                idx = parts[0]
                name = parts[1]
                temp = parts[2]
                gpu_util = parts[3]
                mem_util = parts[4]
                fan = parts[5]
                
                # Handle '[Not Supported]' for fans if necessary, though nvidia-smi usually returns it.
                # If fan is strictly not supported, it might be safer to skip or set to 0.
                if 'Not Supported' in fan:
                    fan = '0'

                labels = f'gpu="{escape_label_value(idx)}",model="{escape_label_value(name)}"'
                
                temps.append(f'nvidia_gpu_temperature_celsius{{{labels}}} {temp}')
                gpu_utils.append(f'nvidia_gpu_utilization_percent{{{labels}}} {gpu_util}')
                mem_utils.append(f'nvidia_mem_utilization_percent{{{labels}}} {mem_util}')
                fans.append(f'nvidia_fan_speed_percent{{{labels}}} {fan}')
            except Exception:
                continue

        add_metric("nvidia_gpu_temperature_celsius", "GPU Temperature in Celsius", "gauge", temps)
        add_metric("nvidia_gpu_utilization_percent", "GPU Utilization in Percent", "gauge", gpu_utils)
        add_metric("nvidia_mem_utilization_percent", "Memory Utilization in Percent", "gauge", mem_utils)
        add_metric("nvidia_fan_speed_percent", "Fan Speed in Percent", "gauge", fans)
        
        return "\n".join(response) + "\n"

if __name__ == "__main__":
    server_address = ('', PORT)
    httpd = ReusableHTTPServer(server_address, PrometheusExporter)
    print(f"Serving NVIDIA metrics on port {PORT}...")
    httpd.serve_forever()
