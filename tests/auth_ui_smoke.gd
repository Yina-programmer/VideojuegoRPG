extends Node

var screen: Control


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	screen = (load("res://scenes/auth/AuthScreen.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var title := screen.get_node("TitleArea/Title") as Label
	if title.text != "ChapiUnderLand" or title.get_theme_font_size("font_size") < 64:
		_fail("El titulo oficial no es protagonista o esta mal escrito")
		return
	for required in [
		"ContentCenter/FormPanel/Margin/MainVBox/WelcomePanel/WelcomeLogin",
		"ContentCenter/FormPanel/Margin/MainVBox/WelcomePanel/WelcomeRegister",
		"ContentCenter/FormPanel/Margin/MainVBox/LoginForm/LoginValue",
		"ContentCenter/FormPanel/Margin/MainVBox/RegisterForm/RegisterEmail",
	]:
		if screen.get_node_or_null(required) == null:
			_fail("Falta un control funcional: %s" % required)
			return
	var capture_path := OS.get_environment("VIDEOJUEGO_AUTH_CAPTURE")
	if not capture_path.is_empty():
		get_viewport().get_texture().get_image().save_png(capture_path.trim_suffix(".png") + "_bienvenida.png")

	screen.call("_show_register")
	var username := screen.get_node("ContentCenter/FormPanel/Margin/MainVBox/RegisterForm/RegisterUsername") as LineEdit
	var email := screen.get_node("ContentCenter/FormPanel/Margin/MainVBox/RegisterForm/RegisterEmail") as LineEdit
	var password := screen.get_node("ContentCenter/FormPanel/Margin/MainVBox/RegisterForm/RegisterPassword") as LineEdit
	var confirmation := screen.get_node("ContentCenter/FormPanel/Margin/MainVBox/RegisterForm/RegisterConfirmation") as LineEdit
	username.text = "ab"
	email.text = "correo-invalido"
	password.text = "123"
	confirmation.text = "456"
	screen.call("_submit_register")
	var status := screen.get_node("ContentCenter/FormPanel/Margin/MainVBox/StatusLabel") as Label
	if status.text.is_empty() or not status.text.contains("usuario"):
		_fail("La validacion local de registro no mostro un mensaje claro")
		return

	var show_password := screen.get_node("ContentCenter/FormPanel/Margin/MainVBox/RegisterForm/ShowRegisterPassword") as Button
	show_password.button_pressed = true
	show_password.toggled.emit(true)
	if password.secret or confirmation.secret:
		_fail("El control mostrar contrasena no funciona")
		return
	if not capture_path.is_empty():
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(capture_path.trim_suffix(".png") + "_registro.png")

	screen.call("_show_login")
	if not (screen.get_node("ContentCenter/FormPanel/Margin/MainVBox/LoginForm") as VBoxContainer).visible:
		_fail("No se puede navegar al inicio de sesion")
		return

	var viewport_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var form_panel := screen.get_node("ContentCenter/FormPanel") as PanelContainer
	if not viewport_rect.encloses(form_panel.get_global_rect()):
		_fail("El formulario sale de la pantalla")
		return

	if not capture_path.is_empty():
		await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		image.save_png(capture_path)

	print("AUTH_UI: titulo, navegacion, campos, validaciones, contrasena y layout verificados")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
