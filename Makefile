all :
	docker-compose up --build

stop :
	docker-compose down

clean : stop
	docker-compose rm h42n42

fclean : stop
	docker system prune -af

re : fclean all

.PHONY : all clean stop re fclean